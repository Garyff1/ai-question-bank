// 多学科富内容渲染组件
// 支持：英语听力（TTS）、SVG 矢量图、数学公式与函数图、化学分子/物理图、统计图表
// 所有组件均为无状态、自包含，可直接嵌入题目详情页

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smart_content_viewer/smart_content_viewer.dart';

import 'features/audio/listening_audio_service.dart';
import 'features/rich_content/chart_data.dart';
import 'features/rich_content/structured_chart_widget.dart';

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
    final colors = Theme.of(context).colorScheme;
    final english = Localizations.localeOf(context).languageCode == 'en';
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
          child = StructuredChartWidget(
            data: StructuredChartData.fromRichContent(data),
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
        color: colors.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                title ?? _defaultTitle(t, english),
                style: TextStyle(
                  color: colors.primary,
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

  String _defaultTitle(String t, bool english) {
    switch (t) {
      case 'listening':
        return english ? 'Listening audio' : '听力音频';
      case 'svg':
        return english ? 'Diagram' : '图形';
      case 'math':
        return english ? 'Formula and diagram' : '公式与图示';
      case 'physics':
        return english ? 'Physics diagram' : '物理示意图';
      case 'chemistry':
        return english ? 'Chemistry structure' : '化学结构图';
      case 'chart':
        return english ? 'Data chart' : '数据图表';
      default:
        return english ? 'Rich content' : '富内容';
    }
  }
}

// ===== 英语听力（在线 TTS） =====

class _ListeningWidget extends StatefulWidget {
  const _ListeningWidget({
    required this.audioText,
    this.voice,
    this.hideText = false,
  });

  final String audioText;
  final String? voice;

  /// v2.7.4: 是否隐藏听力原文（出题/试卷环节隐藏，错题/历史记录展示）
  final bool hideText;

  @override
  State<_ListeningWidget> createState() => _ListeningWidgetState();
}

class _ListeningWidgetState extends State<_ListeningWidget> {
  late final ListeningAudioService _audio;

  @override
  void initState() {
    super.initState();
    _audio = ListeningAudioService();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final english = Localizations.localeOf(context).languageCode == 'en';
    return AnimatedBuilder(
      animation: _audio,
      builder: (context, _) {
        final loading = _audio.state == ListeningPlaybackState.loading;
        final playing = _audio.state == ListeningPlaybackState.playing;
        final paused = _audio.state == ListeningPlaybackState.paused;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: loading
                      ? null
                      : () => playing
                            ? _audio.pause()
                            : _audio.play(
                                widget.audioText,
                                locale: widget.voice,
                              ),
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    loading
                        ? (english ? 'Preparing…' : '准备中…')
                        : (playing
                              ? (english ? 'Pause' : '暂停')
                              : (english ? 'Play audio' : '播放听力')),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : _audio.replay,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(english ? 'Replay' : '重播'),
                ),
                if (playing || paused)
                  IconButton(
                    tooltip: english ? 'Stop' : '停止',
                    onPressed: _audio.stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                  ),
                DropdownButton<double>(
                  value: _audio.rate,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0.35, child: Text('0.75×')),
                    DropdownMenuItem(value: 0.48, child: Text('1.0×')),
                    DropdownMenuItem(value: 0.6, child: Text('1.25×')),
                  ],
                  onChanged: (value) {
                    if (value != null) _audio.setRate(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // v2.7.4: 出题/试卷环节隐藏听力原文，只在错题/历史记录展示
            if (!widget.hideText)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Text(
                  widget.audioText,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colors.onSurface,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_off_rounded,
                      size: 14,
                      color: colors.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        english
                            ? 'The transcript is hidden. Review it after answering in Mistakes or History.'
                            : '听力原文已隐藏，答题后可在错题本/历史记录查看',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_audio.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _audio.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        );
      },
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
    return MathContentViewer(htmlContent: content, minHeight: 80);
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
