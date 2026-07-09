// 多学科富内容渲染组件
// 支持：英语听力（TTS）、SVG 矢量图、数学公式与函数图、化学分子/物理图、统计图表
// 所有组件均为无状态、自包含，可直接嵌入题目详情页

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_content_viewer/smart_content_viewer.dart';

/// 通用富内容块：根据 AI 返回的 [type] 字段分发到对应渲染组件
class RichContentBlock extends StatelessWidget {
  const RichContentBlock({
    super.key,
    required this.type,
    required this.data,
    this.title,
    this.hideListeningText = false,
  });

  /// 富内容类型：
  /// - listening  英语听力（在线 TTS）
  /// - svg        SVG 矢量图
  /// - math       数学（LaTeX/函数图/统计图，使用 smart_content_viewer）
  /// - physics    物理图（forces/circuit/projectile/pendulum/spring/energy/vectors/lens）
  /// - chemistry  化学图（molecule/lewis/benzene/reaction/organic/crystal/orbital）
  /// - chart      统计图（bar/line/pie/histogram）
  /// - html       混合 HTML 内容
  final String type;

  /// 渲染数据：
  /// - listening: {'audio_text': '...', 'voice': 'zh-CN-XiaoxiaoNeural'（可选）}
  /// - svg:       {'svg': '<svg>...</svg>'}
  /// - math:      {'content': '[graph: f(x)=x^2]\n$E=mc^2$'}
  /// - physics:   {'diagram_type': 'forces', 'params': 'angle:30,mass:5'}
  /// - chemistry: {'diagram_type': 'molecule', 'params': 'formula:H2O'}
  /// - chart:     {'chart_type': 'bar', 'data': 'A:30,B:50', 'title': '分布'}
  /// - html:      {'content': '<p>...</p>'}
  final Map<String, dynamic> data;

  /// 可选标题
  final String? title;

  /// v2.7.4: 听力题是否隐藏原文（出题/试卷环节隐藏，错题/历史记录展示）
  final bool hideListeningText;

  @override
  Widget build(BuildContext context) {
    final t = type.toLowerCase();
    Widget? child;
    try {
      switch (t) {
        case 'listening':
          child = _ListeningWidget(
            audioText: data['audio_text'] as String? ?? '',
            voice: data['voice'] as String?,
            hideText: hideListeningText,
          );
          break;
        case 'svg':
          child = _SvgWidget(svg: data['svg'] as String? ?? '');
          break;
        case 'math':
          child = _MathWidget(content: data['content'] as String? ?? '');
          break;
        case 'physics':
          child = _PhysicsWidget(
            diagramType: data['diagram_type'] as String? ?? 'forces',
            params: data['params'] as String? ?? '',
          );
          break;
        case 'chemistry':
          child = _ChemistryWidget(
            diagramType: data['diagram_type'] as String? ?? 'molecule',
            params: data['params'] as String? ?? '',
          );
          break;
        case 'chart':
          child = _ChartWidget(
            chartType: data['chart_type'] as String? ?? 'bar',
            data: data['data'] as String? ?? '',
            chartTitle: data['title'] as String?,
          );
          break;
        case 'html':
          child = _MathWidget(content: data['content'] as String? ?? '');
          break;
      }
    } catch (e) {
      child = _ErrorTip(message: '$e');
    }
    if (child == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                title ?? _defaultTitle(t),
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  String _defaultTitle(String t) {
    switch (t) {
      case 'listening':
        return '听力音频';
      case 'svg':
        return '图形';
      case 'math':
        return '公式与图示';
      case 'physics':
        return '物理示意图';
      case 'chemistry':
        return '化学结构图';
      case 'chart':
        return '数据图表';
      default:
        return '富内容';
    }
  }
}

// ===== 英语听力（在线 TTS） =====

class _ListeningWidget extends StatefulWidget {
  const _ListeningWidget({required this.audioText, this.voice, this.hideText = false});

  final String audioText;
  final String? voice;
  /// v2.7.4: 是否隐藏听力原文（出题/试卷环节隐藏，错题/历史记录展示）
  final bool hideText;

  @override
  State<_ListeningWidget> createState() => _ListeningWidgetState();
}

class _ListeningWidgetState extends State<_ListeningWidget> {
  static AudioPlayer? _player;
  bool _loading = false;
  bool _playing = false;
  String? _audioPath;
  String? _errorMsg;
  FlutterEdgeTts? _tts;

  @override
  void dispose() {
    _stopAndReset();
    super.dispose();
  }

  void _stopAndReset() {
    _player?.stop();
    _player = null;
    _tts?.close();
    _tts = null;
  }

  Future<void> _ensureTts() async {
    if (_tts != null) return;
    // v2.7.3: 根据 voice 字段映射到具体 TTS 声音名
    // AI 返回的 voice 通常是 "en-US" / "zh-CN" 等 locale，不是 voice name
    final voiceStr = widget.voice ?? 'en-US';
    final String ttsVoiceName;
    final String ttsLocale;
    if (voiceStr.startsWith('zh')) {
      ttsVoiceName = 'zh-CN-XiaoxiaoNeural';
      ttsLocale = 'zh-CN';
    } else if (voiceStr.startsWith('en')) {
      ttsVoiceName = 'en-US-AriaNeural';
      ttsLocale = 'en-US';
    } else if (voiceStr.contains('AriaNeural') ||
        voiceStr.contains('XiaoxiaoNeural') ||
        voiceStr.contains('GuyNeural') ||
        voiceStr.contains('YunxiNeural')) {
      // 已经是完整 voice name
      ttsVoiceName = voiceStr;
      ttsLocale = voiceStr.substring(0, 5); // "en-US" or "zh-CN"
    } else {
      // 默认英文
      ttsVoiceName = 'en-US-AriaNeural';
      ttsLocale = 'en-US';
    }
    _tts = FlutterEdgeTts(
      voice: ttsVoiceName,
      voiceLocale: ttsLocale,
      outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
      enableSentenceBoundary: true,
    );
    _player ??= AudioPlayer();
    _player!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playing = state == PlayerState.playing;
          if (!_playing) _loading = false;
        });
      }
    });
  }

  Future<void> _play() async {
    if (widget.audioText.isEmpty) {
      setState(() => _errorMsg = '听力原文为空');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await _ensureTts();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await _tts!.synthesizeToFile(
        widget.audioText,
        audioFilePath: path,
        prosody: const EdgeTtsProsody(rate: '0.95', volume: '100'),
      );
      _audioPath = path;
      if (!mounted) return;
      setState(() => _loading = false);
      await _player!.play(DeviceFileSource(path));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = '播放失败：$e';
      });
    }
  }

  Future<void> _stop() async {
    await _player?.stop();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : (_playing ? _stop : _play),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(_loading ? '合成中...' : (_playing ? '停止' : '播放听力')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_audioPath != null && !_playing && !_loading)
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ],
        ),
        const SizedBox(height: 8),
        // v2.7.4: 出题/试卷环节隐藏听力原文，只在错题/历史记录展示
        if (!widget.hideText)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              widget.audioText,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF1F2937)),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_off_rounded, size: 14, color: Color(0xFF92400E)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '听力原文已隐藏，答题后可在错题本/历史记录查看',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 6),
          Text(
            _errorMsg!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

// ===== SVG 矢量图 =====

class _SvgWidget extends StatelessWidget {
  const _SvgWidget({required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    final s = svg.trim();
    if (s.isEmpty) return const SizedBox.shrink();
    return Center(
      child: SvgPicture.string(
        s,
        width: double.infinity,
        height: 180,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorBuilder: (_, error, __) => _ErrorTip(message: 'SVG 渲染失败：$error'),
      ),
    );
  }
}

// ===== 数学（混合 LaTeX + 标签） =====

class _MathWidget extends StatelessWidget {
  const _MathWidget({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    return MathContentViewer(
      htmlContent: content,
      minHeight: 80,
    );
  }
}

// ===== 物理图 =====

class _PhysicsWidget extends StatelessWidget {
  const _PhysicsWidget({required this.diagramType, required this.params});

  final String diagramType;
  final String params;

  PhysicsDiagramType _resolve() {
    switch (diagramType.toLowerCase()) {
      case 'forces':
        return PhysicsDiagramType.forces;
      case 'circuit':
        return PhysicsDiagramType.circuit;
      case 'projectile':
        return PhysicsDiagramType.projectile;
      case 'pendulum':
        return PhysicsDiagramType.pendulum;
      case 'spring':
        return PhysicsDiagramType.spring;
      case 'energy':
        return PhysicsDiagramType.energy;
      case 'vectors':
        return PhysicsDiagramType.vectors;
      case 'lens':
        return PhysicsDiagramType.lens;
      default:
        return PhysicsDiagramType.forces;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhysicsDiagramViewer(
      diagramType: _resolve(),
      parameters: params,
      height: 240,
      showLabels: true,
    );
  }
}

// ===== 化学图 =====

class _ChemistryWidget extends StatelessWidget {
  const _ChemistryWidget({required this.diagramType, required this.params});

  final String diagramType;
  final String params;

  ChemistryDiagramType _resolve() {
    switch (diagramType.toLowerCase()) {
      case 'molecule':
        return ChemistryDiagramType.molecule;
      case 'lewis':
        return ChemistryDiagramType.lewis;
      case 'benzene':
        return ChemistryDiagramType.benzene;
      case 'reaction':
        return ChemistryDiagramType.reaction;
      case 'organic':
        return ChemistryDiagramType.organic;
      case 'crystal':
        return ChemistryDiagramType.crystal;
      case 'orbital':
        return ChemistryDiagramType.orbital;
      default:
        return ChemistryDiagramType.molecule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChemistryDiagramViewer(
      diagramType: _resolve(),
      parameters: params,
      height: 220,
    );
  }
}

// ===== 统计图 =====

class _ChartWidget extends StatelessWidget {
  const _ChartWidget({
    required this.chartType,
    required this.data,
    this.chartTitle,
  });

  final String chartType;
  final String data;
  final String? chartTitle;

  ChartType _resolve() {
    switch (chartType.toLowerCase()) {
      case 'bar':
        return ChartType.bar;
      case 'line':
        return ChartType.line;
      case 'pie':
        return ChartType.pie;
      case 'histogram':
        return ChartType.histogram;
      default:
        return ChartType.bar;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatisticalChartViewer(
      chartType: _resolve(),
      data: data,
      title: chartTitle,
      height: 240,
      showLegend: true,
      showValues: true,
    );
  }
}

// ===== 错误提示 =====

class _ErrorTip extends StatelessWidget {
  const _ErrorTip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 解析 AI 返回的富内容块列表（JSON 数组）
/// 输入示例：[{"type":"math","data":{"content":"$x^2$"}}, ...]
List<Map<String, dynamic>> parseRichContentList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      })
      .where((m) => m.isNotEmpty)
      .toList(growable: false);
}
