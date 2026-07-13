import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';
import 'rich_content.dart';
import 'dart:io';
import 'dart:typed_data';

const kBlue = Color(0xFF2563EB);
const kBg = Color(0xFFF4F6FB);
const kInk = Color(0xFF0F172A);
const kMuted = Color(0xFF64748B);
const kLine = Color(0xFFE2E8F0);
const kGreen = Color(0xFF10B981);
const kRed = Color(0xFFEF4444);

/// 反馈邮箱：用户在"我的 → 问题反馈"里提交的内容会发到这里。
const kFeedbackEmail = '673819340@qq.com';

// ===== v2.9.0: 音效系统（程序合成，无外部资源）=====

enum SoundType {
  click,    // 按钮点击：短促清脆
  correct,  // 答对：上升和弦
  wrong,    // 答错：下降二音
  star,     // 获得星星：四音上升
  levelup,  // 通关：五音欢呼
  boss,     // Boss出现：低沉三音
  badge,    // 徽章解锁：高音三连
  hint,     // 提示：中音单音
  lose,     // 失败：下降四音
  combo,    // 连击：上升短音
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  AudioPlayer? _player;
  bool _muted = false;
  bool _initialized = false;

  Future<void> _ensure() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setVolume(0.7);
    } catch (_) {
      _player = null;
    }
  }

  void setMuted(bool v) => _muted = v;
  bool get isMuted => _muted;

  Future<void> play(SoundType type) async {
    if (_muted) return;
    await _ensure();
    final p = _player;
    if (p == null) return;
    final bytes = _synth(type);
    if (bytes == null) return;
    try {
      await p.stop();
      await p.play(BytesSource(bytes));
    } catch (_) {
      // 静默失败：音效不应阻塞游戏流程
    }
  }

  /// 合成指定音效的 WAV 字节流
  Uint8List? _synth(SoundType type) {
    switch (type) {
      case SoundType.click:
        return _tone(1200, 0.05, 0.25);
      case SoundType.correct:
        return _melody([659, 784, 1047], 0.07, 0.4);
      case SoundType.wrong:
        return _melody([392, 311], 0.12, 0.35);
      case SoundType.star:
        return _melody([784, 988, 1318, 1568], 0.07, 0.4);
      case SoundType.levelup:
        return _melody([523, 659, 784, 1047, 1318], 0.1, 0.45);
      case SoundType.boss:
        return _melody([196, 165, 131], 0.15, 0.5);
      case SoundType.badge:
        return _melody([1047, 1318, 1568], 0.08, 0.4);
      case SoundType.hint:
        return _tone(587, 0.1, 0.2);
      case SoundType.lose:
        return _melody([392, 349, 311, 262], 0.18, 0.4);
      case SoundType.combo:
        return _tone(988, 0.06, 0.3);
    }
  }

  /// 单个音调（线性淡出包络）
  Uint8List _tone(double freq, double duration, double volume) {
    final sampleRate = 22050;
    final n = (duration * sampleRate).toInt();
    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final env = 1.0 - i / n;
      final s = (sin(2 * pi * freq * t) * 32767 * volume * env).toInt();
      pcm[i] = s.clamp(-32768, 32767);
    }
    return _toWav(pcm, sampleRate);
  }

  /// 多音旋律（每音独立淡出）
  Uint8List _melody(List<double> freqs, double noteDur, double volume) {
    final sampleRate = 22050;
    final nPerNote = (noteDur * sampleRate).toInt();
    final pcm = Int16List(freqs.length * nPerNote);
    var idx = 0;
    for (final f in freqs) {
      for (var i = 0; i < nPerNote; i++) {
        final t = i / sampleRate;
        final env = 1.0 - i / nPerNote;
        final s = (sin(2 * pi * f * t) * 32767 * volume * env).toInt();
        pcm[idx++] = s.clamp(-32768, 32767);
      }
    }
    return _toWav(pcm, sampleRate);
  }

  /// PCM16 → WAV 字节流
  Uint8List _toWav(Int16List pcm, int sampleRate) {
    final dataSize = pcm.lengthInBytes;
    final buf = ByteData(44 + dataSize);
    // RIFF header
    buf.setUint8(0, 0x52); buf.setUint8(1, 0x49); buf.setUint8(2, 0x46); buf.setUint8(3, 0x46);
    buf.setUint32(4, 36 + dataSize, Endian.little);
    buf.setUint8(8, 0x57); buf.setUint8(9, 0x41); buf.setUint8(10, 0x56); buf.setUint8(11, 0x45);
    // fmt chunk
    buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D); buf.setUint8(14, 0x74); buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);                       // PCM
    buf.setUint16(22, 1, Endian.little);                       // mono
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little);          // byte rate
    buf.setUint16(32, 2, Endian.little);                       // block align
    buf.setUint16(34, 16, Endian.little);                      // bits per sample
    // data chunk
    buf.setUint8(36, 0x64); buf.setUint8(37, 0x61); buf.setUint8(38, 0x74); buf.setUint8(39, 0x61);
    buf.setUint32(40, dataSize, Endian.little);
    final bytes = buf.buffer.asUint8List();
    bytes.setRange(44, 44 + dataSize, pcm.buffer.asUint8List());
    return bytes;
  }
}

// ===== v2.9.0: Mini-Game 数据模型 =====

/// Mini-Game 类型：5 种轻量游戏化学习形式
enum MiniGameType {
  matching,   // 配对匹配
  listening,  // 听力选择
  flashcard,  // 闪卡记忆
  reorder,    // 顺序排列
  tapfast,    // 限时快选
  // v2.9.1 新增游戏类型
  spell,      // 单词拼写（字母乱序拼词）
  fillblank,  // 填空拼图（句子挖空填词）
  truefalse,  // 真假快判（滑动卡片判对错）
  linkup,     // 连连看（网格点击配对消除）
}

extension MiniGameTypeX on MiniGameType {
  String get label {
    switch (this) {
      case MiniGameType.matching: return '配对匹配';
      case MiniGameType.listening: return '听力选择';
      case MiniGameType.flashcard: return '闪卡记忆';
      case MiniGameType.reorder: return '顺序排列';
      case MiniGameType.tapfast: return '限时快选';
      case MiniGameType.spell: return '单词拼写';
      case MiniGameType.fillblank: return '填空拼图';
      case MiniGameType.truefalse: return '真假快判';
      case MiniGameType.linkup: return '连连看';
    }
  }
  String get emoji {
    switch (this) {
      case MiniGameType.matching: return '🔗';
      case MiniGameType.listening: return '🎧';
      case MiniGameType.flashcard: return '📇';
      case MiniGameType.reorder: return '📊';
      case MiniGameType.tapfast: return '⚡';
      case MiniGameType.spell: return '🔤';
      case MiniGameType.fillblank: return '🧩';
      case MiniGameType.truefalse: return '👈';
      case MiniGameType.linkup: return '🎯';
    }
  }
  String get desc {
    switch (this) {
      case MiniGameType.matching: return '点击左右两列配对';
      case MiniGameType.listening: return '听音频选答案';
      case MiniGameType.flashcard: return '翻卡记忆再答题';
      case MiniGameType.reorder: return '点击排正确顺序';
      case MiniGameType.tapfast: return '限时快速点击';
      case MiniGameType.spell: return '拖字母拼单词';
      case MiniGameType.fillblank: return '拖词填空';
      case MiniGameType.truefalse: return '滑动判对错';
      case MiniGameType.linkup: return '点击配对消除';
    }
  }
}

/// 单个 Mini-Game 题目（统一数据结构，适配 5 种类型）
class MiniGame {
  const MiniGame({
    required this.type,
    required this.prompt,
    required this.options,
    required this.answer,
    this.audioText,
    this.explanation,
    this.knowledgePoint,
  });

  final MiniGameType type;
  final String prompt;             // 题目/提示文本
  final List<String> options;      // 选项（matching: 左侧terms；reorder: 打乱项；tapfast: 选项）
  final String answer;             // 正确答案（matching: 右侧对应；reorder: 正确顺序索引"0,2,1"；tapfast: "对"/"错"）
  final String? audioText;         // listening 用：TTS 播放文本
  final String? explanation;       // 解析
  final String? knowledgePoint;    // 知识点

  factory MiniGame.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['game_type'] ?? json['type'] ?? 'matching').toString();
    final type = MiniGameType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => MiniGameType.matching,
    );
    final options = (json['options'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final pairs = json['pairs'];
    if (pairs is List && (type == MiniGameType.matching || type == MiniGameType.linkup)) {
      // 配对题：pairs = [{"left":"x","right":"y"}]，options=左侧，answer=右侧(分隔)
      final lefts = pairs.map((p) => (p as Map)['left'].toString()).toList();
      final rights = pairs.map((p) => (p as Map)['right'].toString()).toList();
      return MiniGame(
        type: type,
        prompt: (json['prompt'] ?? '请将左右两列配对').toString(),
        options: lefts,
        answer: rights.join('^A'), // 用 ^A 分隔右侧答案
        audioText: json['audio_text']?.toString(),
        explanation: json['explanation']?.toString(),
        knowledgePoint: json['knowledge_point']?.toString(),
      );
    }
    return MiniGame(
      type: type,
      prompt: (json['prompt'] ?? json['question'] ?? '').toString(),
      options: options,
      answer: (json['answer'] ?? '').toString(),
      audioText: json['audio_text']?.toString(),
      explanation: json['explanation']?.toString(),
      knowledgePoint: json['knowledge_point']?.toString(),
    );
  }
}

/// Mini-Game 关卡结果
class MiniGameLevelResult {
  const MiniGameLevelResult({
    required this.total,
    required this.correct,
    required this.duration,
    required this.wrongs,
  });
  final int total;
  final int correct;
  final Duration duration;
  final List<WrongItem> wrongs;

  bool get allCorrect => correct == total && total > 0;
  bool get fast => duration.inSeconds <= 120;
}

/// v2.9.0: Mini-Game 闯关会话（替代 RPG 模式的 PracticeSession）
class MiniGameSession {
  const MiniGameSession({
    required this.materialName,
    required this.games,
    required this.subject,
    required this.chapter,
    required this.level,
    required this.isBoss,
    required this.startTime,
    required this.lives,
  });
  final String materialName;
  final List<MiniGame> games;
  final String subject;
  final int chapter;
  final int level;
  final bool isBoss;
  final DateTime startTime;
  final int lives; // 剩余生命值，0 则失败
}

// ===== 资料解析（顶层函数，供 Isolate.run() 在后台 Isolate 中调用）=====

String parseMaterialInIsolate((String, List<int>) args) {
  final (filename, bytes) = args;
  return _extractMaterialText(filename, bytes);
}

String _extractMaterialText(String filename, List<int> bytes) {
  final ext = filename.split('.').last.toLowerCase();
  if (['txt', 'md', 'csv', 'json'].contains(ext)) {
    return _decodePlainText(bytes);
  }
  if (ext == 'pdf') {
    return _extractPdfText(bytes);
  }
  if (ext == 'docx') {
    return _extractDocxText(bytes);
  }
  if (ext == 'doc') {
    throw Exception('暂不支持老式 .doc 文件，请另存为 .docx 后再导入');
  }
  throw Exception('暂不支持 .$ext 文件');
}

String _decodePlainText(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}

String _extractPdfText(List<int> bytes) {
  PdfDocument? document;
  try {
    document = PdfDocument(inputBytes: bytes);
    return PdfTextExtractor(document).extractText().trim();
  } catch (_) {
    throw Exception('PDF 解析失败，请确认文件不是扫描件、图片型 PDF 或加密文档');
  } finally {
    document?.dispose();
  }
}

String _extractDocxText(List<int> bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? docFile;
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        docFile = file;
        break;
      }
    }
    if (docFile == null) {
      throw Exception('不是有效的 DOCX 文档');
    }
    final xmlBytes = docFile.readBytes();
    if (xmlBytes == null || xmlBytes.isEmpty) {
      throw Exception('DOCX 正文为空');
    }
    final document = XmlDocument.parse(utf8.decode(xmlBytes));
    final paragraphs = <String>[];
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'p') continue;
      final text = element.descendants
          .whereType<XmlElement>()
          .where((child) => child.name.local == 't')
          .map((child) => child.innerText)
          .join()
          .trim();
      if (text.isNotEmpty) paragraphs.add(text);
    }
    return paragraphs.join('\n').trim();
  } catch (error) {
    // 吞掉底层英文异常，只暴露中文友好提示
    if (error is Exception &&
        error.toString().startsWith('Exception: 不是有效的')) {
      rethrow;
    }
    throw Exception('DOCX 解析失败，请用 Word 另存为 .docx 后再试');
  }
}

void main() {
  runApp(const AiQuestionBankApp());
}

class AiQuestionBankApp extends StatelessWidget {
  const AiQuestionBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI题库',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kBlue),
        scaffoldBackgroundColor: kBg,
        useMaterial3: true,
        fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
      ),
      home: const AppShell(),
    );
  }
}

class StudyMaterial {
  StudyMaterial({
    required this.id,
    required this.name,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StudyMaterial.fromJson(Map<String, dynamic> json) => StudyMaterial(
    id: json['id'] as String,
    name: json['name'] as String,
    content: json['content'] as String,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class ApiConfig {
  const ApiConfig({
    this.provider = 'deepseek',
    this.apiKey = '',
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-v4-flash',
  });

  final String provider;
  final String apiKey;
  final String baseUrl;
  final String model;

  bool get ready =>
      apiKey.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
  };

  factory ApiConfig.fromJson(Map<String, dynamic> json) => ApiConfig(
    provider: json['provider'] as String? ?? 'deepseek',
    apiKey: json['apiKey'] as String? ?? '',
    baseUrl: json['baseUrl'] as String? ?? 'https://api.deepseek.com',
    model: json['model'] as String? ?? 'deepseek-v4-flash',
  );
}

class AiQuestion {
  AiQuestion({
    required this.type,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.richContent = const [],
  });

  final String type;
  final String question;
  final List<String> options;
  final dynamic answer;
  final String explanation;
  /// 富内容块（数学公式、函数图、物理图、化学结构、SVG、统计图、英语听力）
  /// 由 AI 在生成时通过 rich_content 字段返回，详见 rich_content.dart
  final List<Map<String, dynamic>> richContent;

  String get label {
    switch (type) {
      case 'multi_choice':
        return '多选题';
      case 'true_false':
        return '判断题';
      case 'fill':
        return '填空题';
      case 'subjective':
        return '主观题';
      default:
        return '单选题';
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'question': question,
    'options': options,
    'answer': answer,
    'explanation': explanation,
    if (richContent.isNotEmpty) 'rich_content': richContent,
  };

  factory AiQuestion.fromJson(Map<String, dynamic> json) {
    final type = (json['question_type'] ?? json['type'] ?? 'choice').toString();
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((item) => item.toString()).toList()
        : <String>[];
    final questionText = (json['question'] ?? json['title'] ?? '').toString();
    final explanationText =
        (json['explanation'] ?? json['analysis'] ?? '暂无解析').toString();
    // 解析富内容：AI 可在 rich_content 字段返回数组
    List<Map<String, dynamic>> richContent = const [];
    final rawRich = json['rich_content'];
    if (rawRich is List) {
      richContent = rawRich
          .map((item) {
            if (item is Map) return Map<String, dynamic>.from(item);
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList(growable: false);
    }
    // 调试日志：方便排查 AI 是否返回 rich_content
    final qPreview = questionText.length > 30
        ? questionText.substring(0, 30)
        : questionText;
    if (richContent.isNotEmpty) {
      debugPrint('[RichContent] 解析到 ${richContent.length} 个富内容块：'
          '${richContent.map((e) => e['type']).join(',')} | 题干：$qPreview...');
    } else {
      debugPrint('[RichContent] 题目无 rich_content | 题干：$qPreview...');
    }
    // 兜底：AI 未返回 rich_content 时，根据题干内容自动检测数学/化学/物理模式
    // 这是关键修复——很多 AI 模型在严格 JSON 输出时会省略 rich_content 字段
    if (richContent.isEmpty) {
      final fallback = _detectRichContentFallback(questionText, explanationText);
      if (fallback.isNotEmpty) {
        richContent = fallback;
        debugPrint('[RichContent] 兜底生成 ${fallback.length} 个富内容块 | 题干：$qPreview...');
      }
    }
    final questionChart = _extractChartData('$questionText\n$explanationText');
    if (questionChart != null) {
      final chartIndex = richContent.indexWhere(
        (item) => (item['type'] ?? '').toString().toLowerCase() == 'chart',
      );
      if (chartIndex >= 0) {
        richContent[chartIndex] = questionChart;
        debugPrint('[RichContent] 用题干真实数据覆盖 chart 富内容 | 题干：$qPreview...');
      } else {
        richContent.add(questionChart);
        debugPrint('[RichContent] 从题干真实数据补充 chart 富内容 | 题干：$qPreview...');
      }
    }
    return AiQuestion(
      type: _normalizeType(type),
      question: questionText,
      options: _normalizeType(type) == 'true_false' && options.isEmpty
          ? const ['正确', '错误']
          : options,
      answer: json['answer'] ?? json['correct_answer'] ?? '',
      explanation: explanationText,
      richContent: richContent,
    );
  }

  /// 自动兜底：AI 没返回 rich_content 时，根据题干和解析内容自动检测数学/化学/物理模式
  /// 生成基础富内容块，确保用户在 AI 模型不支持 rich_content 时仍能看到图形
  /// v2.7.0 修复乱码：只生成 smart_content_viewer 确定支持的格式
  static List<Map<String, dynamic>> _detectRichContentFallback(
    String question,
    String explanation,
  ) {
    final combined = '$question\n$explanation';
    final result = <Map<String, dynamic>>[];

    // 1. 函数表达式：f(x)=, y=, sin/cos/tan/log/ln
    // 生成 [graph: f(x)=expr] 标签，smart_content_viewer 内置支持
    final funcRegex = RegExp(
      r'(?:f\(x\)|y)\s*=\s*([^\s,。；;,\n]+)',
      caseSensitive: false,
    );
    final funcMatch = funcRegex.firstMatch(combined);
    if (funcMatch != null) {
      var expr = funcMatch.group(1)?.trim() ?? '';
      // 清理非法字符
      expr = expr.replaceAll(RegExp(r'[^\w\+\-\*\/\^\(\)\.]+'), '');
      if (expr.isNotEmpty && expr.length <= 30) {
        result.add({
          'type': 'math',
          'data': {'content': '[graph: f(x)=$expr, x=-10..10, y=-10..10]'},
        });
      }
    }

    // 2. 化学式：只识别 smart_content_viewer 明确支持的物质
    // molecule 类型仅支持：H2O/CO2/NH3/CH4/O2/N2/HCl/NaCl
    // v2.7.1：删除"无明确分子式→默认 H2O"的逻辑，避免题干没具体物质时硬塞图表
    final chemMatch = RegExp(r'\b(H2O|CO2|NH3|CH4|O2|N2|HCl|NaCl)\b')
        .firstMatch(combined);
    if (chemMatch != null) {
      final formula = chemMatch.group(1)!;
      result.add({
        'type': 'chemistry',
        'data': {'diagram_type': 'molecule', 'params': 'formula:$formula'},
      });
    }

    // 3. 物理示意图：v2.7.1 收紧，仅在题干明确包含"图"指示词时才生成
    // 避免题干只是提到"重力""电压"等就硬塞示意图（导致图表与题目重复）
    final hasFigureHint = RegExp(r'如图|下图|上图|图示|示意图|图\(|见图').hasMatch(combined);
    if (hasFigureHint) {
      final physicsChoice = _pickPhysicsDiagram(combined);
      if (physicsChoice != null) {
        result.add({
          'type': 'physics',
          'data': {
            'diagram_type': physicsChoice.type,
            'params': physicsChoice.params,
          },
        });
      }
    }

    // 4. 统计图：v2.7.4 修复 - 从题干/解析中提取真实数据，而非用固定示范数据
    // 仅当题干明确提到统计图类型且能提取到数据时才生成
    final chartData = _extractChartData(combined);
    if (chartData != null) {
      result.add(chartData);
    }

    // v2.7.5: 5. 听力题兜底检测——题干含 "听/Listen/audio/听力" 关键词且包含 ≥4 词英文片段时生成
    // 这能让 AI 即使没返回 rich_content 中的 listening 块，也能从题干反推出来
    final listeningKeyword =
        RegExp(r'听力|听下|听完|听取|listen to|listen carefully|audio', caseSensitive: false)
            .hasMatch(question);
    if (listeningKeyword) {
      // v2.7.5: 用双引号 raw string，字符类里去掉 " 避免冲突（raw string 不识别转义）
      final englishMatch =
          RegExp(r"[A-Za-z][A-Za-z\s,.!?\-';:()]{14,300}").firstMatch(question + '\n' + explanation);
      if (englishMatch != null) {
        final seg = englishMatch
            .group(0)!
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        if (seg.split(RegExp(r'\s+')).length >= 4) {
          result.add({
            'type': 'listening',
            'data': {
              'audio_text': seg,
              'voice': 'en-US',
            },
          });
        }
      }
    }

    return result;
  }

  /// v2.7.6: 从题干/解析中提取统计图数据
  /// 支持格式：标签:数值，标签=数值，标签 数值 等
  /// 仅当能提取到至少 2 组数据时才生成，避免错误示范数据
  /// v2.7.6 修复误差：
  ///   1) 优先从题干（不含解析）提取，避免解析里的计算结果/百分比污染数据
  ///   2) 排除"答案/正确率/选项/分值/编号"等非数据字段
  ///   3) 优先提取"图表附近"的数据，避免全文乱抓
  ///   4) 数值范围合理化（0-10000），排除异常大数/负数
  static Map<String, dynamic>? _extractChartData(String text) {
    // 确定图表类型
    String chartType = 'bar';
    String title = '';
    if (RegExp(r'柱状图|柱形图|条形图').hasMatch(text)) {
      chartType = 'bar';
      title = '柱状图';
    } else if (RegExp(r'折线图|趋势图').hasMatch(text)) {
      chartType = 'line';
      title = '折线图';
    } else if (RegExp(r'饼图|扇形图|占比图').hasMatch(text)) {
      chartType = 'pie';
      title = '饼图';
    } else if (RegExp(r'直方图|频率分布').hasMatch(text)) {
      chartType = 'histogram';
      title = '直方图';
    } else {
      // 没有明确提到图表类型，不生成
      return null;
    }

    // 黑名单标签——这些词后的数值不是图表数据
    const blacklistLabels = {
      '答案', '正确答案', '选项', '正确率', '错误率', '得分', '分值', '满分',
      '总分', '题号', '编号', '页码', '数量', '总数', '人数', '百分比',
      '增长率', '增长', '下降', '幅度', '比例', '占比', '部分',
      '第', '题', '小题', '大题', '解析', '说明', '单位',
    };

    String normalize(String value) => value
        .replaceAll('：', ':')
        .replaceAll('＝', '=')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('，', ',')
        .replaceAll('、', ',')
        .replaceAll('；', ';')
        .replaceAll('％', '%');

    bool validLabel(String label) {
      final cleaned = label.trim();
      if (cleaned.isEmpty || cleaned.length > 10) return false;
      if (blacklistLabels.contains(cleaned)) return false;
      if (RegExp(r'^\d+$').hasMatch(cleaned)) return false;
      if (cleaned.startsWith('答案') ||
          cleaned.startsWith('选项') ||
          cleaned.startsWith('正确') ||
          cleaned.startsWith('错误') ||
          cleaned.startsWith('解析')) {
        return false;
      }
      return true;
    }

    String cleanLabel(String label) => label
        .replaceAll(RegExp(r'^[\s,;:：，、。]+'), '')
        .replaceAll(RegExp(r'(数据|项目|类别|人数|数量|比例|占比)$'), '')
        .trim();

    final dataMap = <String, double>{};

    void addPair(String rawLabel, String valueStr) {
      final label = cleanLabel(rawLabel);
      final value = double.tryParse(valueStr);
      if (value == null) return;
      if (!validLabel(label)) return;
      if (value < 0 || value > 10000) return;
      dataMap[label] = value;
    }

    // 拆分行，逐行找图表关键词附近的数据；如果一行同时含"图"和数据，优先用这行
    final lines = text.split(RegExp(r'[\n。；;！!]'));
    // 候选文本：优先用包含"图"的行，否则用全文
    final candidateLines = lines.where((l) =>
        RegExp(r'图|数据|如下|所示').hasMatch(l) &&
        RegExp(r'\d').hasMatch(l)).toList();
    final searchTexts =
        (candidateLines.isNotEmpty ? candidateLines : [text]).map(normalize);

    void tryExtract(String searchText, RegExp regex, String Function(Match) labelFn, String Function(Match) valueFn) {
      for (final m in regex.allMatches(searchText)) {
        addPair(labelFn(m), valueFn(m));
      }
    }

    for (final searchText in searchTexts) {
      // 优先匹配 "标签:数值" 或 "标签：数值" 格式
      if (dataMap.length < 2) {
        final colonRegex = RegExp(r'([\u4e00-\u9fa5A-Za-z_][\u4e00-\u9fa5A-Za-z0-9_]{0,9})\s*:\s*(\d+(?:\.\d+)?)');
        tryExtract(searchText, colonRegex, (m) => m.group(1)!, (m) => m.group(2)!);
      }
      // 如果冒号格式没匹配到，尝试 "标签=数值" 格式
      if (dataMap.length < 2) {
        dataMap.clear();
        final eqRegex = RegExp(r'([\u4e00-\u9fa5A-Za-z_][\u4e00-\u9fa5A-Za-z0-9_]{0,9})\s*=\s*(\d+(?:\.\d+)?)');
        tryExtract(searchText, eqRegex, (m) => m.group(1)!, (m) => m.group(2)!);
      }
      // 教材常见写法："甲(30)"、"A（12.5）"
      if (dataMap.length < 2) {
        dataMap.clear();
        final parenRegex = RegExp(
          r'([\u4e00-\u9fa5A-Za-z_][\u4e00-\u9fa5A-Za-z0-9_]{0,9})\s*\(\s*(\d+(?:\.\d+)?)\s*(?:人|个|件|分|元|%|％)?\s*\)',
        );
        tryExtract(searchText, parenRegex, (m) => m.group(1)!, (m) => m.group(2)!);
      }
      // 教材自然语言写法："一班有30人"、"甲为42"
      if (dataMap.length < 2) {
        dataMap.clear();
        final naturalRegex = RegExp(
          r'([\u4e00-\u9fa5A-Za-z_][\u4e00-\u9fa5A-Za-z0-9_]{0,7})\s*(?:有|为|是|达到|约)?\s*(\d+(?:\.\d+)?)\s*(?:人|个|件|分|元|%|％)',
        );
        tryExtract(searchText, naturalRegex, (m) => m.group(1)!, (m) => m.group(2)!);
      }
      // 如果还是没匹配到，尝试 "汉字标签 数字" 格式（如"男生 25人"）
      if (dataMap.length < 2) {
        dataMap.clear();
        final spaceRegex = RegExp(r'([\u4e00-\u9fa5A-Za-z_][\u4e00-\u9fa5A-Za-z0-9_]{1,7})\s+(\d+(?:\.\d+)?)');
        tryExtract(searchText, spaceRegex, (m) => m.group(1)!, (m) => m.group(2)!);
      }
      if (dataMap.length >= 2) break;
    }

    // 至少需要 2 组数据才生成图表
    if (dataMap.length < 2) return null;

    // 构建 data 字符串
    final dataStr = dataMap.entries.take(10).map((e) {
      final v = e.value == e.value.roundToDouble()
          ? e.value.round().toString()
          : e.value.toString();
      return '${e.key}:$v';
    }).join(',');

    return {
      'type': 'chart',
      'data': {
        'chart_type': chartType,
        'data': dataStr,
        'title': title,
      },
    };
  }

  /// 根据题干关键词选择最合适的物理示意图类型 + 合理默认参数
  /// 返回 null 表示题干不涉及物理
  static _PhysicsDiagramChoice? _pickPhysicsDiagram(String text) {
    if (RegExp(r'受力|重力|支持力|摩擦力').hasMatch(text)) {
      return _PhysicsDiagramChoice('forces', 'angle:30,mass:5,friction:0.3');
    }
    if (RegExp(r'电路|电压|电流|电阻|欧姆').hasMatch(text)) {
      return _PhysicsDiagramChoice('circuit', 'voltage:12,resistance:100');
    }
    if (RegExp(r'平抛|抛体|投射').hasMatch(text)) {
      return _PhysicsDiagramChoice('projectile', 'v0:20,angle:45,g:9.81');
    }
    if (RegExp(r'单摆|摆动').hasMatch(text)) {
      return _PhysicsDiagramChoice('pendulum', 'length:1,angle:30,mass:1');
    }
    if (RegExp(r'弹簧|弹力').hasMatch(text)) {
      return _PhysicsDiagramChoice('spring', 'k:100,extension:0.1,mass:1');
    }
    if (RegExp(r'动能|势能|机械能').hasMatch(text)) {
      return _PhysicsDiagramChoice('energy', 'ep:50,ec:30');
    }
    if (RegExp(r'透镜|焦距|凸透镜|凹透镜|成像').hasMatch(text)) {
      return _PhysicsDiagramChoice('lens', 'f:10,object:30,height:10');
    }
    return null;
  }
}

class _PhysicsDiagramChoice {
  final String type;
  final String params;
  const _PhysicsDiagramChoice(this.type, this.params);
}

/// 试卷题目：复用 AiQuestion 的字段，多一个 section（大题题号，如 一、选择题）
class PaperQuestion {
  const PaperQuestion({
    required this.section,
    required this.indexInSection,
    required this.question,
    this.knowledgePoint = '',
  });

  final String section;
  final int indexInSection;
  final AiQuestion question;
  /// AI 标注的知识点（5-12 字）。为空时回退到"综合"。
  final String knowledgePoint;

  Map<String, dynamic> toJson() => {
        'section': section,
        'indexInSection': indexInSection,
        'question': question.toJson(),
        'knowledgePoint': knowledgePoint,
      };

  factory PaperQuestion.fromJson(Map<String, dynamic> json) => PaperQuestion(
        section: json['section'] as String? ?? '',
        indexInSection: json['indexInSection'] as int? ?? 0,
        question: AiQuestion.fromJson(
          Map<String, dynamic>.from(json['question'] as Map? ?? {}),
        ),
        knowledgePoint: json['knowledgePoint'] as String? ?? '',
      );
}

/// v2.7.2: 听力题条目（用于音频下载时携带大题/小问编号）
class _ListeningItem {
  const _ListeningItem({
    required this.sectionIdx,
    required this.sectionName,
    required this.questionIdx,
    required this.indexInSection,
    required this.audioText,
    required this.voice,
  });
  final int sectionIdx;
  final String sectionName;
  final int questionIdx;
  final int indexInSection;
  final String audioText;
  final String voice;
}

/// 一次生成的试卷
class Paper {
  const Paper({
    required this.id,
    required this.subject,
    required this.gradeLevel,
    required this.pageCount,
    required this.materialName,
    required this.questions,
    required this.createdAt,
    this.scoreConfig = const PaperScoreConfig(),
  });

  final String id;
  final String subject;
  final String gradeLevel;
  final int pageCount;
  final String materialName;
  final List<PaperQuestion> questions;
  final DateTime createdAt;
  final PaperScoreConfig scoreConfig;

  /// 按题型自动计算总分
  int get totalScore {
    var total = 0;
    for (final q in questions) {
      final t = q.question.type;
      if (t == 'choice' || t == 'multi_choice') {
        total += scoreConfig.choiceScore;
      } else if (t == 'fill') {
        total += scoreConfig.fillScore;
      } else if (t == 'true_false') {
        total += scoreConfig.judgeScore;
      } else {
        total += scoreConfig.subjectiveScore;
      }
    }
    // 若用户指定了百分制等固定总分，则以此为准
    final fixed = scoreConfig.effectiveTotal;
    return fixed > 0 ? fixed : total;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'gradeLevel': gradeLevel,
        'pageCount': pageCount,
        'materialName': materialName,
        'questions': questions.map((q) => q.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'scoreConfig': scoreConfig.toJson(),
      };

  factory Paper.fromJson(Map<String, dynamic> json) => Paper(
        id: json['id'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        gradeLevel: json['gradeLevel'] as String? ?? '',
        pageCount: json['pageCount'] as int? ?? 4,
        materialName: json['materialName'] as String? ?? '',
        questions: ((json['questions'] as List?) ?? [])
            .map((item) => PaperQuestion.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        scoreConfig: json['scoreConfig'] is Map
            ? PaperScoreConfig.fromJson(
                Map<String, dynamic>.from(json['scoreConfig'] as Map))
            : const PaperScoreConfig(),
      );
}

/// 试卷分值配置：可指定总分（百分制等）和各题型小题分值
class PaperScoreConfig {
  const PaperScoreConfig({
    this.totalMode = 0,
    this.customTotal = 100,
    this.choiceScore = 3,
    this.fillScore = 4,
    this.judgeScore = 2,
    this.subjectiveScore = 10,
  });

  /// 0=自动（按各题型分值累加），1=100，2=120，3=150，4=自定义
  final int totalMode;
  final int customTotal;
  final int choiceScore;
  final int fillScore;
  final int judgeScore;
  final int subjectiveScore;

  /// 实际用于显示的"满分"
  int get effectiveTotal {
    switch (totalMode) {
      case 1:
        return 100;
      case 2:
        return 120;
      case 3:
        return 150;
      case 4:
        return customTotal;
      default:
        return 0; // 0 表示自动
    }
  }

  Map<String, dynamic> toJson() => {
        'totalMode': totalMode,
        'customTotal': customTotal,
        'choiceScore': choiceScore,
        'fillScore': fillScore,
        'judgeScore': judgeScore,
        'subjectiveScore': subjectiveScore,
      };

  factory PaperScoreConfig.fromJson(Map<String, dynamic> json) =>
      PaperScoreConfig(
        totalMode: json['totalMode'] as int? ?? 0,
        customTotal: json['customTotal'] as int? ?? 100,
        choiceScore: json['choiceScore'] as int? ?? 3,
        fillScore: json['fillScore'] as int? ?? 4,
        judgeScore: json['judgeScore'] as int? ?? 2,
        subjectiveScore: json['subjectiveScore'] as int? ?? 10,
      );
}

/// 试卷题型分布模板：定义各大题题量
class PaperTemplate {
  const PaperTemplate({
    this.choiceCount = 0,
    this.fillCount = 0,
    this.judgeCount = 0,
    this.subjectiveCount = 0,
  });

  final int choiceCount;
  final int fillCount;
  final int judgeCount;
  final int subjectiveCount;

  int get totalCount =>
      choiceCount + fillCount + judgeCount + subjectiveCount;

  /// 默认模板：根据学段+类型+学科+页数推算题量
  /// 参考国内中考/高考/期末/周测真实结构
  factory PaperTemplate.defaultFor({
    required String subject,
    required String gradeLevel,
    required int pageCount,
  }) {
    // stage / examType 拆分（gradeLevel 形如 "初中·期末"）
    final parts = gradeLevel.split('·');
    final stage = parts.isNotEmpty ? parts[0] : '';
    final examType = parts.length > 1 ? parts[1] : '';

    // 1. 基础题量：按页数（每页约 5 题，保证不超长）
    final base = (pageCount * 5).clamp(8, 36);

    // 2. 学科偏好：决定各题型占比
    // 文科（语文/英语/政治/历史）：偏选择 + 主观（作文/简答）
    // 理科（数学/物理/化学）：偏选择 + 填空 + 解答
    // 生物/地理：偏选择（常为会考/合格考）
    final liberalArts = ['语文', '英语', '政治', '历史'];
    final science = ['数学', '物理', '化学'];
    final bioGeo = ['生物', '地理'];

    int choice, fill, judge, subjective;

    if (liberalArts.contains(subject)) {
      // 文科：选择题占 50%，主观题占 30%，填空 20%，无判断
      choice = (base * 0.5).round();
      subjective = (base * 0.3).round();
      fill = base - choice - subjective;
      judge = 0;
    } else if (science.contains(subject)) {
      // 理科：选择 35%，填空 25%，判断 10%，解答 30%
      choice = (base * 0.35).round();
      fill = (base * 0.25).round();
      judge = (base * 0.10).round();
      subjective = base - choice - fill - judge;
    } else if (bioGeo.contains(subject)) {
      // 生物/地理：选择 70%，非选择题 30%
      choice = (base * 0.7).round();
      subjective = base - choice;
      fill = 0;
      judge = 0;
    } else {
      // 通用：选择 40%，填空 25%，判断 15%，解答 20%
      choice = (base * 0.4).round();
      fill = (base * 0.25).round();
      judge = (base * 0.15).round();
      subjective = base - choice - fill - judge;
    }

    // 3. 学段调整
    if (stage == '小学') {
      // 小学：判断题多一些，解答题少一些
      judge = (judge + base * 0.10).round().clamp(0, 8);
      subjective = (subjective - base * 0.05).round().clamp(2, 10);
    } else if (stage == '成年人') {
      // 成年人/职业考试：选择题占主导
      choice = (choice + base * 0.10).round();
      subjective = (subjective - base * 0.10).round().clamp(1, 8);
    }

    // 4. 考试类型调整
    if (examType == '周测' || examType == '小测' || examType == '单元测') {
      // 周测/小测：题量精简，主观题少
      subjective = (subjective * 0.6).round().clamp(1, 5);
      choice = (choice + 2).clamp(2, 15);
    } else if (examType == '中考模拟' || examType == '高考模拟') {
      // 中高考模拟：主观题占比稍高
      subjective = (subjective + 1).clamp(3, 10);
    }

    // 5. 确保至少有 1 道主观题，避免试卷过于简单
    if (subjective < 1) subjective = 1;

    final total = choice + fill + judge + subjective;
    // 按比例缩放回 base
    if (total > base) {
      final ratio = base / total;
      choice = (choice * ratio).round().clamp(1, 30);
      fill = (fill * ratio).round().clamp(0, 20);
      judge = (judge * ratio).round().clamp(0, 10);
      subjective = (subjective * ratio).round().clamp(1, 10);
    }

    return PaperTemplate(
      choiceCount: choice,
      fillCount: fill,
      judgeCount: judge,
      subjectiveCount: subjective,
    );
  }

  Map<String, dynamic> toJson() => {
        'choiceCount': choiceCount,
        'fillCount': fillCount,
        'judgeCount': judgeCount,
        'subjectiveCount': subjectiveCount,
      };

  factory PaperTemplate.fromJson(Map<String, dynamic> json) => PaperTemplate(
        choiceCount: json['choiceCount'] as int? ?? 0,
        fillCount: json['fillCount'] as int? ?? 0,
        judgeCount: json['judgeCount'] as int? ?? 0,
        subjectiveCount: json['subjectiveCount'] as int? ?? 0,
      );

  @override
  String toString() =>
      'PaperTemplate(choice=$choiceCount, fill=$fillCount, judge=$judgeCount, subjective=$subjectiveCount, total=$totalCount)';
}

class PracticeRecord {
  PracticeRecord({
    required this.materialName,
    required this.total,
    required this.correct,
    required this.createdAt,
    this.xpEarned = 0,
    this.isWrongCardChallenge = false,
    List<QuestionStat>? questionStats,
  }) : questionStats = questionStats ?? const [];

  final String materialName;
  final int total;
  final int correct;
  final DateTime createdAt;
  final int xpEarned;
  final bool isWrongCardChallenge;
  final List<QuestionStat> questionStats;

  int get wrong => max(0, total - correct);
  int get accuracy => total == 0 ? 0 : (correct / total * 100).round();

  Map<String, dynamic> toJson() => {
    'materialName': materialName,
    'total': total,
    'correct': correct,
    'createdAt': createdAt.toIso8601String(),
    'xpEarned': xpEarned,
    'isWrongCardChallenge': isWrongCardChallenge,
    'questionStats': questionStats.map((q) => q.toJson()).toList(),
  };

  factory PracticeRecord.fromJson(Map<String, dynamic> json) => PracticeRecord(
    materialName: json['materialName'] as String? ?? '未知资料',
    total: json['total'] as int? ?? 0,
    correct: json['correct'] as int? ?? 0,
    xpEarned: json['xpEarned'] as int? ?? 0,
    isWrongCardChallenge: json['isWrongCardChallenge'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    questionStats: ((json['questionStats'] as List?) ?? [])
        .map((item) => QuestionStat.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList(),
  );
}

/// 单题统计：题型 + 是否正确 + 选项分布 + 知识点
class QuestionStat {
  const QuestionStat({
    required this.type,
    required this.isCorrect,
    required this.answerLetter,
    required this.knowledgePoint,
  });

  /// 'choice' | 'multi_choice' | 'fill' | 'true_false' | 'subjective'
  final String type;
  final bool isCorrect;
  /// 选择题的正确选项字母（如 A/B/C/D）；非选择题为空
  final String answerLetter;
  /// 知识点（目前用 section/题目前缀近似，未来可由 AI 显式标注）
  final String knowledgePoint;

  Map<String, dynamic> toJson() => {
    'type': type,
    'isCorrect': isCorrect,
    'answerLetter': answerLetter,
    'knowledgePoint': knowledgePoint,
  };

  factory QuestionStat.fromJson(Map<String, dynamic> json) => QuestionStat(
    type: json['type'] as String? ?? 'choice',
    isCorrect: json['isCorrect'] as bool? ?? false,
    answerLetter: json['answerLetter'] as String? ?? '',
    knowledgePoint: json['knowledgePoint'] as String? ?? '综合',
  );
}

class WrongItem {
  WrongItem({
    required this.materialName,
    required this.question,
    required this.userAnswer,
    required this.createdAt,
  });

  final String materialName;
  final AiQuestion question;
  final String userAnswer;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'materialName': materialName,
    'question': question.toJson(),
    'userAnswer': userAnswer,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WrongItem.fromJson(Map<String, dynamic> json) => WrongItem(
    materialName: json['materialName'] as String? ?? '未知资料',
    question: AiQuestion.fromJson(
      Map<String, dynamic>.from(json['question'] as Map? ?? {}),
    ),
    userAnswer: json['userAnswer'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

String wrongQuestionKey(AiQuestion question) {
  final answer = question.answer == null ? '' : jsonEncode(question.answer);
  return [
    question.type.trim().toLowerCase(),
    question.question.replaceAll(RegExp(r'\s+'), ' ').trim(),
    answer.replaceAll(RegExp(r'\s+'), ' ').trim(),
  ].join('|');
}

List<WrongItem> mergeWrongItems(
  List<WrongItem> existing,
  List<WrongItem> incoming, {
  Iterable<AiQuestion> resolvedQuestions = const [],
  int limit = 500,
}) {
  final resolvedKeys = resolvedQuestions.map(wrongQuestionKey).toSet();
  final incomingKeys =
      incoming.map((item) => wrongQuestionKey(item.question)).toSet();
  final kept = existing
      .where((item) {
        final key = wrongQuestionKey(item.question);
        return !resolvedKeys.contains(key) && !incomingKeys.contains(key);
      })
      .toList(growable: false);
  final merged = <WrongItem>[...incoming, ...kept];
  return merged.length > limit ? merged.sublist(0, limit) : merged;
}

class XpProfile {
  const XpProfile({
    this.totalXp = 0,
    this.checkinStreak = 0,
    this.lastCheckinDate = '',
    this.boostExpiresAt,
  });

  final int totalXp;
  final int checkinStreak;
  final String lastCheckinDate;
  final DateTime? boostExpiresAt;

  int get level => totalXp ~/ 100 + 1;
  int get levelProgress => totalXp % 100;

  bool isBoostActive([DateTime? now]) {
    final expiresAt = boostExpiresAt;
    if (expiresAt == null) return false;
    return expiresAt.isAfter(now ?? DateTime.now());
  }

  int activeMultiplier([DateTime? now]) => isBoostActive(now) ? 3 : 1;

  Duration boostRemaining([DateTime? now]) {
    final expiresAt = boostExpiresAt;
    if (expiresAt == null) return Duration.zero;
    final left = expiresAt.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  XpProfile copyWith({
    int? totalXp,
    int? checkinStreak,
    String? lastCheckinDate,
    DateTime? boostExpiresAt,
  }) => XpProfile(
    totalXp: totalXp ?? this.totalXp,
    checkinStreak: checkinStreak ?? this.checkinStreak,
    lastCheckinDate: lastCheckinDate ?? this.lastCheckinDate,
    boostExpiresAt: boostExpiresAt ?? this.boostExpiresAt,
  );

  Map<String, dynamic> toJson() => {
    'totalXp': totalXp,
    'checkinStreak': checkinStreak,
    'lastCheckinDate': lastCheckinDate,
    'boostExpiresAt': boostExpiresAt?.toIso8601String(),
  };

  factory XpProfile.fromJson(Map<String, dynamic> json) => XpProfile(
    totalXp: json['totalXp'] as int? ?? 0,
    checkinStreak: json['checkinStreak'] as int? ?? 0,
    lastCheckinDate: json['lastCheckinDate'] as String? ?? '',
    boostExpiresAt: DateTime.tryParse(json['boostExpiresAt'] as String? ?? ''),
  );
}

class XpSettlement {
  const XpSettlement({
    required this.baseXp,
    required this.multiplier,
    required this.finalXp,
    this.boostActivated = false,
    this.isCheckin = false,
    this.streak = 0,
  });

  final int baseXp;
  final int multiplier;
  final int finalXp;
  final bool boostActivated;
  final bool isCheckin;
  final int streak;
}

// === RPG 闯关系统 ===
// v2.8.0: 新增闯关 RPG 游戏模式 —— 章节地图 + 关卡难度梯度 + Boss 关 + 三星 + 徽章
// 数据模型：RpgProgress 持久化到 SharedPreferences key 'rpg_progress_v1'
// 独立 XP 体系：totalRpgXp 不影响现有 totalXp 等级
// 关卡标识格式："章节-关卡"，如 "1-3" 表示第1章第3关

/// 徽章定义
class RpgBadge {
  const RpgBadge({
    required this.id,
    required this.emoji,
    required this.name,
    required this.desc,
    required this.color,
  });
  final String id;
  final String emoji;
  final String name;
  final String desc;
  final Color color;
}

/// 全部徽章定义（5 枚）
const _kRpgBadges = <RpgBadge>[
  RpgBadge(id: 'first_clear', emoji: '🏆', name: '初露锋芒', desc: '首次通关任意关卡', color: Color(0xFF3B82F6)),
  RpgBadge(id: 'chapter_3star', emoji: '🎖️', name: '完美主义者', desc: '单章全部三星', color: Color(0xFFF59E0B)),
  RpgBadge(id: 'no_error_3', emoji: '⚡', name: '雷霆连击', desc: '连续 3 关零错题', color: Color(0xFF10B981)),
  RpgBadge(id: 'boss_first', emoji: '🛡️', name: '屠龙勇士', desc: '首次通关 Boss 关', color: Color(0xFFEF4444)),
  RpgBadge(id: 'all_clear', emoji: '📚', name: '学海无涯', desc: '全部章节通关', color: Color(0xFFA855F7)),
];

/// 学科章节预设
/// v2.8.0: 按学科自动划分章节，每章 5 关（前4关普通 + 第5关Boss）
class RpgChapter {
  const RpgChapter({
    required this.id,
    required this.subject,
    required this.title,
    required this.subtitle,
    required this.difficulty,
    required this.color,
    required this.icon,
  });
  final int id;        // 章节序号 1-based
  final String subject;
  final String title;
  final String subtitle;
  final String difficulty; // 简单/中等/困难
  final Color color;
  final IconData icon;
}

/// 学科 → 章节列表（自动推荐）
/// 根据用户上传资料时选择的学科返回对应章节预设
List<RpgChapter> _rpgChaptersForSubject(String subject) {
  // v2.9.1: 通用学科叙事冒险主题 — 3 章故事旅程
  const base = <RpgChapter>[
    RpgChapter(id: 1, subject: '通用', title: '第1章 · 启程之森', subtitle: '基础概念 · 入门探索', difficulty: '简单', color: Color(0xFF3B82F6), icon: Icons.forest_rounded),
    RpgChapter(id: 2, subject: '通用', title: '第2章 · 智慧之峰', subtitle: '进阶应用 · 攀登挑战', difficulty: '中等', color: Color(0xFF10B981), icon: Icons.terrain_rounded),
    RpgChapter(id: 3, subject: '通用', title: '第3章 · 真理之殿', subtitle: '综合实战 · 终极考验', difficulty: '困难', color: Color(0xFFF59E0B), icon: Icons.emoji_events_rounded),
  ];
  switch (subject) {
    case '数学':
      return const [
        RpgChapter(id: 1, subject: '数学', title: '第1章 · 代数基础', subtitle: '方程·不等式·函数', difficulty: '简单', color: Color(0xFF3B82F6), icon: Icons.calculate_rounded),
        RpgChapter(id: 2, subject: '数学', title: '第2章 · 几何进阶', subtitle: '三角形·圆·坐标', difficulty: '中等', color: Color(0xFF10B981), icon: Icons.category_rounded),
        RpgChapter(id: 3, subject: '数学', title: '第3章 · 统计综合', subtitle: '数据·概率·建模', difficulty: '困难', color: Color(0xFFF59E0B), icon: Icons.bar_chart_rounded),
      ];
    case '语文':
      return const [
        RpgChapter(id: 1, subject: '语文', title: '第1章 · 字词基础', subtitle: '字音·字形·词义', difficulty: '简单', color: Color(0xFF3B82F6), icon: Icons.menu_book_rounded),
        RpgChapter(id: 2, subject: '语文', title: '第2章 · 句段进阶', subtitle: '病句·修辞·连贯', difficulty: '中等', color: Color(0xFF10B981), icon: Icons.edit_note_rounded),
        RpgChapter(id: 3, subject: '语文', title: '第3章 · 阅读写作', subtitle: '古诗文·现代文·作文', difficulty: '困难', color: Color(0xFFF59E0B), icon: Icons.auto_stories_rounded),
      ];
    case '英语':
      return const [
        RpgChapter(id: 1, subject: '英语', title: '第1章 · 词汇语法', subtitle: '词性·时态·句型', difficulty: '简单', color: Color(0xFF3B82F6), icon: Icons.translate_rounded),
        RpgChapter(id: 2, subject: '英语', title: '第2章 · 阅读理解', subtitle: '主旨·细节·推断', difficulty: '中等', color: Color(0xFF10B981), icon: Icons.chrome_reader_mode_rounded),
        RpgChapter(id: 3, subject: '英语', title: '第3章 · 写作综合', subtitle: '翻译·作文·完形', difficulty: '困难', color: Color(0xFFF59E0B), icon: Icons.edit_rounded),
      ];
    case '物理':
      return const [
        RpgChapter(id: 1, subject: '物理', title: '第1章 · 力学基础', subtitle: '运动·力·牛顿定律', difficulty: '简单', color: Color(0xFF3B82F6), icon: Icons.speed_rounded),
        RpgChapter(id: 2, subject: '物理', title: '第2章 · 电学进阶', subtitle: '电路·电磁·电磁感应', difficulty: '中等', color: Color(0xFF10B981), icon: Icons.bolt_rounded),
        RpgChapter(id: 3, subject: '物理', title: '第3章 · 综合应用', subtitle: '热学·光学·近代物理', difficulty: '困难', color: Color(0xFFF59E0B), icon: Icons.science_rounded),
      ];
    case '化学':
      return const [
        RpgChapter(id: 1, subject: '化学', title: '第1章 · 物质结构', subtitle: '原子·分子·元素周期', difficulty: '简单', color: Color(0xFF3B82F6), icon: Icons.scatter_plot_rounded),
        RpgChapter(id: 2, subject: '化学', title: '第2章 · 化学反应', subtitle: '方程式·平衡·速率', difficulty: '中等', color: Color(0xFF10B981), icon: Icons.sync_rounded),
        RpgChapter(id: 3, subject: '化学', title: '第3章 · 有机综合', subtitle: '烃·衍生物·实验', difficulty: '困难', color: Color(0xFFF59E0B), icon: Icons.water_drop_rounded),
      ];
    default:
      return base;
  }
}

/// 玩家 RPG 进度（持久化）
class RpgProgress {
  const RpgProgress({
    this.currentChapter = 1,
    this.currentLevel = 1,
    this.stars = const {},
    this.unlockedBadges = const {},
    this.totalRpgXp = 0,
    this.noErrorStreak = 0,  // 连续零错题关卡数
  });

  final int currentChapter;
  final int currentLevel;
  final Map<String, int> stars; // {"1-1": 3, "1-2": 2}
  final Set<String> unlockedBadges;
  final int totalRpgXp;
  final int noErrorStreak;

  /// 关卡是否已解锁
  bool isUnlocked(int chapter, int level) {
    if (chapter < currentChapter) return true;
    if (chapter == currentChapter && level <= currentLevel) return true;
    return false;
  }

  /// 关卡已通关
  bool isCleared(String levelKey) => (stars[levelKey] ?? 0) > 0;

  /// 关卡三星
  bool is3Star(String levelKey) => (stars[levelKey] ?? 0) >= 3;

  /// 章节是否全部三星
  bool isChapterAll3Star(int chapter) {
    for (var lv = 1; lv <= 5; lv++) {
      if (!is3Star('$chapter-$lv')) return false;
    }
    return true;
  }

  RpgProgress copyWith({
    int? currentChapter,
    int? currentLevel,
    Map<String, int>? stars,
    Set<String>? unlockedBadges,
    int? totalRpgXp,
    int? noErrorStreak,
  }) => RpgProgress(
    currentChapter: currentChapter ?? this.currentChapter,
    currentLevel: currentLevel ?? this.currentLevel,
    stars: stars ?? this.stars,
    unlockedBadges: unlockedBadges ?? this.unlockedBadges,
    totalRpgXp: totalRpgXp ?? this.totalRpgXp,
    noErrorStreak: noErrorStreak ?? this.noErrorStreak,
  );

  Map<String, dynamic> toJson() => {
    'currentChapter': currentChapter,
    'currentLevel': currentLevel,
    'stars': stars,
    'unlockedBadges': unlockedBadges.toList(),
    'totalRpgXp': totalRpgXp,
    'noErrorStreak': noErrorStreak,
  };

  factory RpgProgress.fromJson(Map<String, dynamic> json) => RpgProgress(
    currentChapter: json['currentChapter'] as int? ?? 1,
    currentLevel: json['currentLevel'] as int? ?? 1,
    stars: ((json['stars'] as Map<String, dynamic>?) ?? {}).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    ),
    unlockedBadges: ((json['unlockedBadges'] as List?) ?? [])
        .map((e) => e.toString())
        .toSet(),
    totalRpgXp: json['totalRpgXp'] as int? ?? 0,
    noErrorStreak: json['noErrorStreak'] as int? ?? 0,
  );
}

/// RPG 关卡结算信息
class RpgLevelResult {
  const RpgLevelResult({
    required this.chapter,
    required this.level,
    required this.stars,
    required this.earnedXp,
    required this.newBadges,
    required this.chapterCleared,
    required this.allCleared,
  });
  final int chapter;
  final int level;
  final int stars;          // 0-3
  final int earnedXp;       // 本次获得 XP（含三星加成）
  final List<RpgBadge> newBadges; // 新解锁徽章
  final bool chapterCleared;  // 本章通关
  final bool allCleared;      // 全部章节通关
}

/// 通关结算页直接返回给 Navigator 的用户动作。
/// 使用返回值代替跨页面回调，避免弹窗关闭和下一页启动发生路由竞态。
enum RpgCompletionAction { backToMap, next }

class RpgCompletionPayload {
  const RpgCompletionPayload({
    required this.result,
    required this.chapter,
    required this.level,
  });

  final RpgLevelResult result;
  final int chapter;
  final int level;
}

/// 闯关模式专用题型轮转。听力题只属于普通出题/试卷功能，闯关中不再生成，
/// 避免部分设备的 TTS/播放器在关卡销毁时触发原生崩溃。
List<String> rpgMiniGameTypesFor({
  required String subject,
  required int chapter,
  required int level,
  int count = 5,
}) {
  final baseTypes = subject == '英语'
      ? <String>[
          'spell',
          'matching',
          'fillblank',
          'tapfast',
          'flashcard',
          'reorder',
          'truefalse',
          'linkup',
        ]
      : subject == '语文'
          ? <String>[
              'matching',
              'fillblank',
              'truefalse',
              'flashcard',
              'spell',
              'reorder',
              'tapfast',
              'linkup',
            ]
          : <String>[
              'matching',
              'reorder',
              'tapfast',
              'linkup',
              'truefalse',
              'fillblank',
              'flashcard',
              'spell',
            ];
  final offset = (chapter * 3 + level) % baseTypes.length;
  return List<String>.generate(
    count.clamp(1, baseTypes.length),
    (index) => baseTypes[(index + offset) % baseTypes.length],
  );
}

/// 富内容题型统一采用 25% 目标占比，天然落在用户要求的 20%-30% 区间。
int richContentTargetCount(int total) {
  if (total <= 0) return 0;
  return (total * 0.25).round().clamp(1, total);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _materialsKey = 'materials_v1';
  static const _recordsKey = 'records_v1';
  static const _wrongsKey = 'wrongs_v1';
  static const _papersKey = 'papers_v1';
  static const _configKey = 'api_config_v1';
  static const _onboardingSeenKey = 'onboarding_seen_v1';
  static const _xpProfileKey = 'xp_profile_v1';
  static const _enableRichKey = 'enable_rich_v2';
  static const _enableListeningKey = 'enable_listening_v1';
  // v2.7.3: 独立持久化的每日练习趋势日志，删除历史记录不影响本周趋势
  static const _practiceLogKey = 'practice_log_v1';
  // v2.8.0: 闯关 RPG 进度持久化
  static const _rpgProgressKey = 'rpg_progress_v1';

  final Set<String> _selectedTypes = {'choice'};
  final List<String> _audiences = const [
    '通用',
    '小学生',
    '初中生',
    '高中生',
    '大学生',
    '考研',
    '职业考试',
  ];

  List<StudyMaterial> _materials = [];
  List<PracticeRecord> _records = [];
  List<WrongItem> _wrongs = [];
  List<Paper> _papers = [];
  // v2.7.3: 每日练习趋势日志（date_key -> 当日做题数），独立于 records，删除历史记录不影响趋势
  Map<String, int> _practiceLog = {};
  ApiConfig _config = const ApiConfig();
  XpProfile _xpProfile = const XpProfile();
  StudyMaterial? _selectedMaterial;
  int _tab = 0;
  int _questionCount = 5;
  String _audience = '通用';
  bool _loading = true;
  bool _generating = false;
  bool _parsing = false;
  bool _paperGenerating = false;
  bool _enableRichContent = false;
  bool _enableListening = false;
  String? _parseFileName;
  bool _onboardingQueued = false;
  PracticeSession? _session;
  Timer? _boostTicker;
  // v2.8.0: 闯关 RPG 状态
  RpgProgress _rpgProgress = const RpgProgress();
  String _rpgSubject = '通用'; // 当前正在闯关的学科
  // v2.9.1: 当前闯关所选教材（教材选择环节）
  StudyMaterial? _rpgMaterial;
  // v2.9.1: RPG 关卡加载中标志（独立于 _rpgSubject 判断）
  bool _rpgGenerating = false;
  // v2.9.0: Mini-Game 闯关会话
  MiniGameSession? _miniGameSession;
  // 防止关卡组件重复回调或用户连续点击时并发执行两次结算。
  bool _completingMiniGameLevel = false;
  // 结算层由 AppShell 自己托管，不再通过 Navigator 弹窗返回动作。
  // 这样可避免听力播放器/小游戏页面销毁与弹窗路由 pop 同帧发生时的崩溃。
  RpgCompletionPayload? _pendingRpgCompletion;
  bool _handlingRpgCompletion = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // v2.7.2: 保证开屏动画至少展示 2.5 秒，避免一闪而过
    final splashStart = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    // 每一类数据单独 try-catch：即使某类本地数据损坏，也只丢那一类，App 仍能启动
    List<StudyMaterial> materials;
    try {
      materials = _decodeList(prefs.getString(_materialsKey))
          .map((item) => StudyMaterial.fromJson(item))
          .toList();
    } catch (_) {
      materials = [];
    }
    List<PracticeRecord> records;
    try {
      records = _decodeList(prefs.getString(_recordsKey))
          .map((item) => PracticeRecord.fromJson(item))
          .toList();
    } catch (_) {
      records = [];
    }
    // 30 天自动清理：超过 30 天的练习记录自动移除
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final originalCount = records.length;
    records = records.where((r) => r.createdAt.isAfter(cutoff)).toList();
    if (records.length != originalCount) {
      // 异步写回清理后的列表，避免阻塞启动
      Future.microtask(() async {
        final p = await SharedPreferences.getInstance();
        await p.setString(
          _recordsKey,
          jsonEncode(records.map((item) => item.toJson()).toList()),
        );
      });
    }
    List<WrongItem> wrongs;
    try {
      wrongs = _decodeList(prefs.getString(_wrongsKey))
          .map((item) => WrongItem.fromJson(item))
          .toList();
    } catch (_) {
      wrongs = [];
    }
    // 错题收纳 30 天自动清理：超过 30 天的错题自动移除（与练习记录一致）
    final wrongCutoff = DateTime.now().subtract(const Duration(days: 30));
    final originalWrongCount = wrongs.length;
    wrongs = wrongs.where((w) => w.createdAt.isAfter(wrongCutoff)).toList();
    if (wrongs.length != originalWrongCount) {
      Future.microtask(() async {
        final p = await SharedPreferences.getInstance();
        await p.setString(
          _wrongsKey,
          jsonEncode(wrongs.map((item) => item.toJson()).toList()),
        );
      });
    }
    List<Paper> papers;
    try {
      papers = _decodeList(prefs.getString(_papersKey))
          .map((item) => Paper.fromJson(item))
          .toList();
    } catch (_) {
      papers = [];
    }
    ApiConfig config;
    try {
      final configJson = prefs.getString(_configKey);
      config = configJson == null
          ? const ApiConfig()
          : ApiConfig.fromJson(
              jsonDecode(configJson) as Map<String, dynamic>);
    } catch (_) {
      config = const ApiConfig();
    }
    XpProfile xpProfile;
    try {
      final xpJson = prefs.getString(_xpProfileKey);
      xpProfile = xpJson == null
          ? const XpProfile()
          : XpProfile.fromJson(jsonDecode(xpJson) as Map<String, dynamic>);
    } catch (_) {
      xpProfile = const XpProfile();
    }
    final onboardingSeen = prefs.getBool(_onboardingSeenKey) ?? false;
    // v2 版本 key 强制覆盖：旧版用户可能存储了 false，这里强制设为 true
    final enableRich = prefs.getBool(_enableRichKey) ?? true;
    if (!prefs.containsKey(_enableRichKey)) {
      await prefs.setBool(_enableRichKey, true);
    }
    final enableListening = prefs.getBool(_enableListeningKey) ?? false;
    if (!prefs.containsKey(_enableListeningKey)) {
      await prefs.setBool(_enableListeningKey, false);
    }
    // v2.7.3: 加载每日练习趋势日志（独立于 records）
    Map<String, int> practiceLog = {};
    try {
      final logJson = prefs.getString(_practiceLogKey);
      if (logJson != null) {
        final decoded = jsonDecode(logJson) as Map<String, dynamic>;
        practiceLog = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}
    // v2.8.0: 加载 RPG 闯关进度
    RpgProgress rpgProgress;
    try {
      final rpgJson = prefs.getString(_rpgProgressKey);
      rpgProgress = rpgJson == null
          ? const RpgProgress()
          : RpgProgress.fromJson(jsonDecode(rpgJson) as Map<String, dynamic>);
    } catch (_) {
      rpgProgress = const RpgProgress();
    }
    setState(() {
      _materials = materials;
      _records = records;
      _wrongs = wrongs;
      _papers = papers;
      _practiceLog = practiceLog;
      _rpgProgress = rpgProgress;
      _selectedMaterial = materials.isEmpty ? null : materials.first;
      _config = config;
      _xpProfile = xpProfile;
      _enableRichContent = enableRich;
      _enableListening = enableListening;
    });
    // v2.7.2: 开屏动画最小展示 2.5 秒
    final elapsed = DateTime.now().difference(splashStart).inMilliseconds;
    const minSplashMs = 2500;
    if (elapsed < minSplashMs) {
      await Future.delayed(Duration(milliseconds: minSplashMs - elapsed));
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _syncBoostTicker();
    if (!onboardingSeen && !_onboardingQueued && mounted) {
      _onboardingQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding());
    }
  }

  @override
  void dispose() {
    _boostTicker?.cancel();
    super.dispose();
  }

  static List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _materialsKey,
      jsonEncode(_materials.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recordsKey,
      jsonEncode(_records.map((item) => item.toJson()).toList()),
    );
  }

  /// v2.7.3: 保存每日练习趋势日志（独立于 records，删除历史记录不影响趋势）
  Future<void> _savePracticeLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _practiceLogKey,
      jsonEncode(_practiceLog),
    );
  }

  Future<void> _saveWrongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _wrongsKey,
      jsonEncode(_wrongs.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _savePapers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _papersKey,
      jsonEncode(_papers.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveXpProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_xpProfileKey, jsonEncode(_xpProfile.toJson()));
  }

  // v2.8.0: 持久化 RPG 闯关进度
  Future<void> _saveRpgProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rpgProgressKey, jsonEncode(_rpgProgress.toJson()));
  }

  Future<void> _saveConfig(ApiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
    setState(() => _config = config);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _confirmDanger({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _showOnboarding() async {
    if (!mounted) return;
    final finished = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const OnboardingGuide(),
    );
    if (finished == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingSeenKey, true);
    }
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    HapticFeedback.lightImpact();
    setState(() => _tab = index);
  }

  Future<void> _openConfigPage() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            title: const Text('API 配置'),
            backgroundColor: kBg,
            surfaceTintColor: Colors.transparent,
          ),
          body: SafeArea(
            child: ConfigPage(config: _config, onSave: _saveConfig),
          ),
        ),
      ),
    );
  }

  void _openPaperViewer(Paper paper) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PaperViewer(
          paper: paper,
          onDownload: () => _downloadPaper(paper),
          onDownloadAnswer: () => _downloadPaperAnswer(paper),
          onDownloadAudio: () => _downloadPaperAudio(paper),
        ),
      ),
    );
  }

  Future<void> _deletePaper(String id, {String? name}) async {
    final ok = await _confirmDanger(
      title: '删除试卷？',
      message: name == null
          ? '删除后无法恢复，确认要删除这份试卷吗？'
          : '即将删除试卷：$name\n删除后无法恢复，确认要删除吗？',
      confirmText: '删除',
    );
    if (!ok || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _papers.removeWhere((p) => p.id == id));
    await _savePapers();
    _showSnack('试卷已删除');
  }

  Future<void> _downloadPaper(Paper paper) async {
    HapticFeedback.selectionClick();
    try {
      final pdfBytes = await PaperPdfService.buildPaperPdf(paper);
      final stamp = paper.createdAt;
      final fname =
          '试卷_${paper.subject}_${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}_${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}.pdf';
      final savedPath = await FilePicker.saveFile(
        fileName: fname,
        bytes: Uint8List.fromList(pdfBytes),
      );
      if (savedPath == null) {
        _showSnack('已取消导出');
      } else {
        _showSnack('试卷 PDF 已保存到：$savedPath');
      }
    } catch (error) {
      _showSnack('导出失败：${error.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _downloadPaperAnswer(Paper paper) async {
    HapticFeedback.selectionClick();
    try {
      final pdfBytes = await PaperPdfService.buildAnswerPdf(paper);
      final stamp = paper.createdAt;
      final fname =
          '答案_${paper.subject}_${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}_${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}.pdf';
      final savedPath = await FilePicker.saveFile(
        fileName: fname,
        bytes: Uint8List.fromList(pdfBytes),
      );
      if (savedPath == null) {
        _showSnack('已取消导出');
      } else {
        _showSnack('答案 PDF 已保存到：$savedPath');
      }
    } catch (error) {
      _showSnack('导出失败：${error.toString().replaceFirst('Exception: ', '')}');
    }
  }

  /// v2.7.2: 下载试卷听力音频（mp3 格式）
  /// 重写：合并为单个 mp3 文件，每题前加中文引导"现在是第X大题第Y小问"，
  /// 听力原文重复 3 遍，每遍之间停顿 1 秒，结束后提示"下一题"
  Future<void> _downloadPaperAudio(Paper paper) async {
    HapticFeedback.selectionClick();
    // v2.7.3: 按试卷预览的实际结构计算大题号与小问号，确保与试卷显示一致
    // 试卷预览中：大题按 section 分组顺序编号（一、二、三...），小问按组内顺序编号（1、2、3...）
    final listeningItems = <_ListeningItem>[];
    final sectionOrder = <String>[];
    final sectionCounter = <String, int>{};
    for (var i = 0; i < paper.questions.length; i++) {
      final pq = paper.questions[i];
      final sec = pq.section.isEmpty ? '题目' : pq.section;
      if (!sectionOrder.contains(sec)) {
        sectionOrder.add(sec);
        sectionCounter[sec] = 0;
      }
      sectionCounter[sec] = (sectionCounter[sec] ?? 0) + 1;
      final sectionIdx = sectionOrder.indexOf(sec) + 1;
      final indexInSection = sectionCounter[sec]!;
      final q = pq.question;
      for (final rc in q.richContent) {
        if ((rc['type'] ?? '').toString() == 'listening') {
          final data = rc['data'] is Map
              ? Map<String, dynamic>.from(rc['data'] as Map)
              : <String, dynamic>{};
          listeningItems.add(_ListeningItem(
            sectionIdx: sectionIdx,
            sectionName: sec,
            questionIdx: i + 1,
            indexInSection: indexInSection,
            audioText: (data['audio_text'] ?? '').toString().trim(),
            voice: (data['voice'] ?? 'en-US').toString(),
          ));
        }
      }
    }
    if (listeningItems.isEmpty) {
      _showSnack('本试卷未包含听力题，无需导出音频');
      return;
    }
    setState(() => _paperGenerating = true);
    try {
      final stamp = paper.createdAt;
      final dateStr =
          '${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}_${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}';
      final tmpDir = await getTemporaryDirectory();
      // 中文 TTS 用于引导语，英文 TTS 用于听力原文
      final cnTts = FlutterEdgeTts(
        voice: 'zh-CN-XiaoxiaoNeural',
        voiceLocale: 'zh-CN',
        outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
        enableSentenceBoundary: true,
      );
      // 逐条生成 mp3 片段，最后合并
      final segments = <File>[];
      for (var idx = 0; idx < listeningItems.length; idx++) {
        final item = listeningItems[idx];
        if (item.audioText.isEmpty) continue;
        // 1. 中文引导："现在是第X大题，第Y小问。请注意听。"
        final cnNum = _toChineseNum(item.sectionIdx);
        final qNum = _toChineseNum(item.indexInSection);
        final intro = '现在是第$cnNum大题，第$qNum小问。请注意听。';
        final introPath = '${tmpDir.path}/seg_${idx}_intro.mp3';
        await cnTts.synthesizeToFile(
          intro,
          audioFilePath: introPath,
          prosody: const EdgeTtsProsody(rate: '0.95', volume: '100'),
        );
        segments.add(File(introPath));
        // 短暂停顿（用空文件代替，这里直接用 1 秒静音段）
        // 简化：在听力原文前后加句号，TTS 会自然停顿
        // 2. 听力原文重复 3 遍（英文 TTS）
        final enTts = FlutterEdgeTts(
          voice: item.voice.startsWith('zh')
              ? 'zh-CN-XiaoxiaoNeural'
              : 'en-US-AriaNeural',
          voiceLocale: item.voice.startsWith('zh') ? 'zh-CN' : 'en-US',
          outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
          enableSentenceBoundary: true,
        );
        for (var repeat = 1; repeat <= 3; repeat++) {
          final repeatCn = _toChineseNum(repeat);
          final prefix = '第$repeatCn遍。';
          // 中文引导+英文原文混合：用中文 TTS 念"第X遍"，再用英文 TTS 念原文
          final prefixPath = '${tmpDir.path}/seg_${idx}_r${repeat}_pre.mp3';
          await cnTts.synthesizeToFile(
            prefix,
            audioFilePath: prefixPath,
            prosody: const EdgeTtsProsody(rate: '0.95', volume: '100'),
          );
          segments.add(File(prefixPath));
          // 英文原文
          final contentPath = '${tmpDir.path}/seg_${idx}_r${repeat}_content.mp3';
          await enTts.synthesizeToFile(
            item.audioText,
            audioFilePath: contentPath,
            prosody: const EdgeTtsProsody(rate: '0.9', volume: '100'),
          );
          segments.add(File(contentPath));
          await enTts.close();
        }
        // 3. 结束提示
        if (idx < listeningItems.length - 1) {
          const outro = '本题结束。请准备下一题。';
          final outroPath = '${tmpDir.path}/seg_${idx}_outro.mp3';
          await cnTts.synthesizeToFile(
            outro,
            audioFilePath: outroPath,
            prosody: const EdgeTtsProsody(rate: '0.95', volume: '100'),
          );
          segments.add(File(outroPath));
        }
      }
      await cnTts.close();
      if (segments.isEmpty) {
        _showSnack('听力原文为空，无法生成音频');
        return;
      }
      // 合并所有片段为一个 mp3 文件
      // 简单合并：直接拼接字节（mp3 帧可拼接，播放器会自动处理）
      final mergedBytes = <int>[];
      for (final seg in segments) {
        if (await seg.exists()) {
          mergedBytes.addAll(await seg.readAsBytes());
        }
      }
      final fname = '听力_${paper.subject}_$dateStr.mp3';
      final savedPath = await FilePicker.saveFile(
        fileName: fname,
        bytes: Uint8List.fromList(mergedBytes),
      );
      if (savedPath == null) {
        _showSnack('已取消导出');
      } else {
        _showSnack('听力音频（${listeningItems.length} 题，每题3遍）已保存到：$savedPath');
      }
      // 清理临时片段文件
      for (final seg in segments) {
        try {
          if (await seg.exists()) await seg.delete();
        } catch (_) {}
      }
    } catch (error) {
      // v2.7.2: 详细错误信息，避免英文报错让用户困惑
      final errStr = error.toString();
      String userMsg;
      if (errStr.contains('SocketException') || errStr.contains('HandshakeException')) {
        userMsg = '网络连接失败，请检查网络后重试';
      } else if (errStr.contains('FileSystemException') || errStr.contains('Permission')) {
        userMsg = '文件保存失败，请检查存储权限';
      } else if (errStr.contains('TimeoutException')) {
        userMsg = 'TTS 合成超时，请稍后重试';
      } else {
        userMsg = '音频导出失败：${errStr.replaceFirst('Exception: ', '')}';
      }
      _showSnack(userMsg);
    } finally {
      if (mounted) setState(() => _paperGenerating = false);
    }
  }

  /// 阿拉伯数字转中文（用于听力引导"第X大题"）
  static String _toChineseNum(int n) {
    const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (n <= 10) return digits[n];
    if (n < 20) return '十${digits[n - 10]}';
    if (n < 100) {
      final tens = n ~/ 10;
      final ones = n % 10;
      return '${digits[tens]}十${ones == 0 ? '' : digits[ones]}';
    }
    return n.toString();
  }

  void _openFeedback() {
    HapticFeedback.selectionClick();
    final contentCtrl = TextEditingController();
    String type = 'Bug 反馈';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendEmail() async {
              final content = contentCtrl.text.trim();
              if (content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请先填写反馈内容'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final subject = '[题库反馈] $type';
              final body = StringBuffer()
                ..writeln('反馈类型：$type')
                ..writeln('---')
                ..writeln(content)
                ..writeln('---')
                ..writeln('App 版本：v${const String.fromEnvironment('appVersion', defaultValue: '2.0.x')}');
              final uri = Uri(
                scheme: 'mailto',
                path: kFeedbackEmail,
                query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body.toString())}',
              );
              final ok = await launchUrl(uri);
              if (!ok) {
                // 兜底：复制邮箱到剪贴板，让用户手动发
                await Clipboard.setData(
                  const ClipboardData(text: kFeedbackEmail),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('未检测到邮件 App，邮箱已复制：$kFeedbackEmail'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
              if (context.mounted) Navigator.pop(context);
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18, 14, 18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: kLine,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        '问题反馈',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '描述你遇到的 bug 或想法，点发送会调起邮件 App，自动带上内容发到我们的邮箱。',
                        style: TextStyle(color: kMuted, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '反馈类型',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Bug 反馈', '功能建议', '其他'].map((t) {
                          final selected = t == type;
                          return ChoiceChip(
                            label: Text(t),
                            selected: selected,
                            onSelected: (_) => setSheetState(() => type = t),
                            selectedColor: const Color(0xFFEFF6FF),
                            labelStyle: TextStyle(
                              color: selected ? kBlue : kInk,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selected ? kBlue : kLine,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentCtrl,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: '反馈内容',
                          hintText: '例如：在某页面点了某按钮后出现什么现象……',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: sendEmail,
                        icon: const Icon(Icons.mail_outline_rounded),
                        label: const Text('通过邮件发送'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '收件邮箱：$kFeedbackEmail',
                        style: const TextStyle(color: kMuted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _syncBoostTicker() {
    _boostTicker?.cancel();
    if (!_xpProfile.isBoostActive()) return;
    _boostTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_xpProfile.isBoostActive()) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  Future<void> _addMaterial(String name, String content) async {
    if (name.trim().isEmpty || content.trim().isEmpty) {
      _showSnack('资料名称和内容不能为空');
      return;
    }
    if (_materials.length >= 20) {
      HapticFeedback.heavyImpact();
      _showSnack('最多只能导入 20 份资料，请先删除旧资料再导入新的');
      return;
    }
    final item = StudyMaterial(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    setState(() {
      _materials.insert(0, item);
      _selectedMaterial = item;
    });
    await _saveMaterials();
  }

  Future<void> _deleteMaterial(StudyMaterial material) async {
    final ok = await _confirmDanger(
      title: '删除资料？',
      message: '删除后，这份资料将从本机移除；已生成的练习记录和错题不会被自动删除。',
      confirmText: '确认删除',
    );
    if (!ok || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _materials.removeWhere((item) => item.id == material.id);
      if (_selectedMaterial?.id == material.id) {
        _selectedMaterial = _materials.isEmpty ? null : _materials.first;
      }
    });
    await _saveMaterials();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'docx', 'doc'],
      );
    } catch (error) {
      _showSnack('文件选择器异常：${error.toString().replaceFirst('Exception: ', '')}');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final name = file.name;
    final path = file.path;
    final pickedBytes = file.bytes;

    setState(() {
      _parsing = true;
      _parseFileName = name;
    });
    try {
      // 优先用 file.path 重新读取字节（更可靠，避免大文件被 file_picker 截断）
      List<int> bytes;
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        } else if (pickedBytes != null) {
          bytes = pickedBytes;
        } else {
          _showSnack('没有读取到文件内容（路径不存在且无字节）');
          return;
        }
      } else if (pickedBytes != null) {
        bytes = pickedBytes;
      } else {
        _showSnack('没有读取到文件内容');
        return;
      }

      // 用 compute 把解析丢到后台线程
      final content = await compute(parseMaterialInIsolate, (name, bytes));

      if (content.trim().length < 10) {
        _showSnack('没有解析到足够的文字内容，请检查文件是否为扫描件或空文档');
        return;
      }
      await _addMaterial(name, content);
      _showSnack('已导入并解析：$name');
    } catch (error) {
      // 兜底：吞掉所有底层异常，只暴露中文友好提示
      final msg = error.toString().replaceFirst('Exception: ', '');
      if (msg.contains('PDF') || name.toLowerCase().endsWith('.pdf')) {
        _showSnack('PDF 解析失败：请确认不是扫描件/图片型 PDF/加密文档');
      } else if (msg.contains('DOCX') ||
          name.toLowerCase().endsWith('.docx')) {
        _showSnack('DOCX 解析失败：请用 Word 另存为 .docx 后再试');
      } else {
        _showSnack('文件解析失败：$msg');
      }
    } finally {
      if (mounted) {
        setState(() {
          _parsing = false;
          _parseFileName = null;
        });
      }
    }
  }

  /// 拍照识题功能已暂时移除：DeepSeek API 不支持图片输入，本地 OCR 中文识别准确度不足。
  /// 待后续 AI API 支持多模态后再恢复。

  Future<void> _openPasteDialog() async {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('粘贴学习资料'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '资料名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                minLines: 8,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: '资料内容',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  hintText: '可粘贴任意文本：从 PDF/Word 复制的文字、网页内容、笔记等',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '提示：粘贴文本适合短资料；长资料建议使用「导入文件」。',
                style: TextStyle(fontSize: 11, color: kMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存资料'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await _addMaterial(nameCtrl.text, contentCtrl.text);
    }
  }

  Future<void> _addDemoMaterial() async {
    const content = '''
光合作用是绿色植物利用叶绿体，在光照条件下把二氧化碳和水转化为有机物，并释放氧气的过程。叶绿素能够吸收光能，光合作用主要包括光反应和暗反应两个阶段。光合作用不仅为植物自身提供能量，也为生态系统中的其他生物提供食物和氧气。

影响光合作用强度的因素包括光照强度、二氧化碳浓度、温度和水分。适当增强光照或提高二氧化碳浓度可以促进光合作用，但超过一定范围后促进作用会减弱。''';
    await _addMaterial('生物复习：光合作用.txt', content);
  }

  Future<void> _generateQuestions() async {
    final material = _selectedMaterial;
    if (material == null) {
      _showSnack('请先添加学习资料');
      return;
    }
    if (_selectedTypes.isEmpty) {
      _showSnack('请至少选择一种题型');
      return;
    }
    if (!_config.ready) {
      _showSnack('请先配置大模型 API，正在跳转...');
      _openConfigPage();
      return;
    }
    setState(() => _generating = true);
    try {
      final questions = await AiService.generateQuestions(
        config: _config,
        material: material.content,
        types: _selectedTypes.toList(),
        count: _questionCount,
        audience: _audience,
        enableRichContent: _enableRichContent,
        enableListening: _enableListening,
      );
      if (questions.isEmpty) {
        _showSnack('AI 没有返回有效题目，请换个模型或缩短资料');
      } else {
        setState(() {
          _session = PracticeSession(
            materialName: material.name,
            questions: questions.take(_questionCount).toList(),
            xpMultiplier: _xpProfile.activeMultiplier(),
          );
        });
      }
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _generatePaper({
    required String subject,
    required String gradeLevel,
    required int pageCount,
    required StudyMaterial material,
    PaperScoreConfig scoreConfig = const PaperScoreConfig(),
    PaperTemplate? template,
    String chapterRange = '',
    String knowledgePointSpec = '',
    int listeningCount = 0,
  }) async {
    if (!_config.ready) {
      _showSnack('请先配置大模型 API，正在跳转...');
      _openConfigPage();
      return;
    }
    setState(() => _paperGenerating = true);
    try {
      final questions = await AiService.generatePaper(
        config: _config,
        material: material.content,
        subject: subject,
        gradeLevel: gradeLevel,
        pageCount: pageCount,
        scoreConfig: scoreConfig,
        template: template,
        enableRichContent: _enableRichContent,
        enableListening: _enableListening,
        chapterRange: chapterRange,
        knowledgePointSpec: knowledgePointSpec,
        listeningCount: listeningCount,
      );
      if (questions.isEmpty) {
        _showSnack('AI 没有返回有效试题，请换个模型或缩短资料');
      } else {
        final paper = Paper(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          subject: subject,
          gradeLevel: gradeLevel,
          pageCount: pageCount,
          materialName: material.name,
          questions: questions,
          createdAt: DateTime.now(),
          scoreConfig: scoreConfig,
        );
        setState(() {
          _papers.insert(0, paper);
        });
        await _savePapers();
        if (mounted) {
          _showSnack('试卷生成成功（共 ${questions.length} 题）');
        }
      }
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _paperGenerating = false);
    }
  }

  Future<void> _startWrongCardChallenge() async {
    if (!mounted) return;
    if (_wrongs.isEmpty) {
      _showSnack('暂无错题，先完成一组练习再来抽卡吧');
      return;
    }
    final pool = [..._wrongs]..shuffle(Random());
    final picked = pool.take(min(5, pool.length)).toList();
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WrongCardDrawDialog(
        count: picked.length,
        canActivateBoost: picked.length >= 5,
      ),
    );
    if (proceed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _session = PracticeSession(
        materialName: '错题抽卡挑战',
        questions: picked.map((item) => item.question).toList(),
        sourceWrongs: picked,
        isWrongCardChallenge: true,
        xpMultiplier: _xpProfile.activeMultiplier(),
      );
    });
  }

  // v2.8.0: 打开 RPG 章节地图
  // v2.9.1: 教材选择替换学科选择，统一用「通用」学科，难度由章节(基础/进阶/综合)体现
  Future<void> _openRpgMap() async {
    if (_materials.isEmpty) {
      _showSnack('请先导入学习资料');
      return;
    }
    if (!_config.ready) {
      _showSnack('请先配置大模型 API');
      _openConfigPage();
      return;
    }
    // v2.9.1: 教材选择环节
    StudyMaterial? material;
    if (_materials.length == 1) {
      material = _materials.first;
    } else {
      material = await showDialog<StudyMaterial>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择闯关教材'),
          children: _materials
              .map((m) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF6366F1)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                Text('${m.content.length} 字', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
      if (material == null || !mounted) return;
    }
    // v2.9.1: 统一用「通用」学科，难度由章节体现（基础→进阶→综合）
    const subject = '通用';
    _rpgSubject = subject;
    _rpgMaterial = material;
    await _pushRpgMap(material, subject);
  }

  Future<void> _pushRpgMap(StudyMaterial material, String subject) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RpgMapPage(
          material: material,
          subject: subject,
          progress: _rpgProgress,
          onStartLevel: _startRpgChallenge,
        ),
      ),
    );
  }

  Future<void> _returnToRpgMap() async {
    final material = _rpgMaterial;
    if (!mounted) return;
    if (material == null) {
      _showSnack('闯关资料已不存在，请重新选择资料');
      return;
    }
    await _pushRpgMap(material, _rpgSubject);
  }

  // v2.8.0: 开始 RPG 关卡挑战
  Future<void> _startRpgChallenge(int chapter, int level, {bool popMap = true}) async {
    // 关闭地图页
    if (popMap) {
      if (!mounted) return;
      Navigator.of(context).pop();
      // 等地图路由退出后再展示关卡介绍，避免两个路由动画重叠。
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
    }
    if (!_config.ready) {
      _showSnack('请先配置大模型 API');
      return;
    }
    final material = _rpgMaterial ??
        _selectedMaterial ??
        (_materials.isNotEmpty ? _materials.first : null);
    if (material == null) {
      _showSnack('学习资料已不存在，请重新导入后再闯关');
      return;
    }
    final subject = _rpgSubject;
    final isBoss = level == 5;
    // 显示关卡介绍
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RpgLevelIntroDialog(
        chapter: chapter,
        level: level,
        subject: subject,
        progress: _rpgProgress,
      ),
    );
    if (proceed != true || !mounted) return;
    // v2.9.0: 显示游戏化加载页，替代之前无声等待
    // v2.9.1: 用独立 _rpgGenerating 标志，避免 _rpgSubject 判断失效
    setState(() {
      _generating = true;
      _rpgGenerating = true;
    });
    // Boss 出现音效
    if (isBoss) {
      SoundService.instance.play(SoundType.boss);
    }
    try {
      final games = await AiService.generateMiniGames(
        config: _config,
        material: material.content,
        subject: subject,
        chapter: chapter,
        level: level,
        audience: _audience,
      );
      if (games.isEmpty) {
        _showSnack('AI 没有返回有效关卡，请重试');
        return;
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      SoundService.instance.play(SoundType.levelup);
      setState(() {
        _miniGameSession = MiniGameSession(
          materialName: '$subject · 第$chapter章 第$level关',
          games: games,
          subject: subject,
          chapter: chapter,
          level: level,
          isBoss: isBoss,
          startTime: DateTime.now(),
          lives: isBoss ? 5 : 3,
        );
      });
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() {
        _generating = false;
        _rpgGenerating = false;
      });
    }
  }

  // v2.9.0: Mini-Game 关卡完成回调
  Future<void> _completeMiniGameLevel(MiniGameLevelResult result) async {
    if (!mounted || _completingMiniGameLevel) return;
    final completedSession = _miniGameSession;
    if (completedSession == null) return;
    _completingMiniGameLevel = true;

    // 转换为 PracticeResult 以复用 _settleRpg
    final chapter = completedSession.chapter;
    final level = completedSession.level;
    final startTime = completedSession.startTime;
    final fakeResult = PracticeResult(
      materialName: completedSession.materialName,
      total: result.total,
      correct: result.correct,
      wrongs: result.wrongs,
      questions: const [],
      correctFlags: List.filled(result.total, true),
      isWrongCardChallenge: false,
      xpMultiplier: 1,
      gameMode: 'rpg',
      rpgChapter: chapter,
      rpgLevel: level,
      rpgStartTime: startTime,
    );
    final rpgResult = _settleRpg(fakeResult);

    // 记录到练习历史
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (!mounted) {
      _completingMiniGameLevel = false;
      return;
    }
    setState(() {
      _records.insert(0, PracticeRecord(
        materialName: completedSession.materialName,
        total: result.total,
        correct: result.correct,
        createdAt: now,
        xpEarned: rpgResult.earnedXp,
      ));
      if (_records.length > 500) _records = _records.sublist(0, 500);
      _wrongs.insertAll(0, result.wrongs);
      if (_wrongs.length > 500) _wrongs = _wrongs.sublist(0, 500);
      // 更新练习趋势
      _practiceLog[dateKey] = (_practiceLog[dateKey] ?? 0) + 1;
      _miniGameSession = null;
    });
    try {
      await _saveRecords();
      await _saveWrongs();
      await _savePracticeLog();
      await _saveRpgProgress();
    } catch (error) {
      _showSnack('关卡记录保存失败：${error.toString().replaceFirst('Exception: ', '')}');
    }

    HapticFeedback.heavyImpact();
    if (rpgResult.stars > 0) {
      SoundService.instance.play(SoundType.levelup);
    } else {
      SoundService.instance.play(SoundType.lose);
    }
    // 新徽章音效
    if (rpgResult.newBadges.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        SoundService.instance.play(SoundType.badge);
      });
    }

    if (!mounted) {
      _completingMiniGameLevel = false;
      return;
    }
    setState(() {
      _pendingRpgCompletion = RpgCompletionPayload(
        result: rpgResult,
        chapter: chapter,
        level: level,
      );
      _completingMiniGameLevel = false;
    });
  }

  Future<void> _consumeRpgCompletionAction(
    RpgCompletionAction action,
  ) async {
    final payload = _pendingRpgCompletion;
    if (!mounted || payload == null || _handlingRpgCompletion) return;
    setState(() {
      _handlingRpgCompletion = true;
      _pendingRpgCompletion = null;
    });
    // 等结算层真正从 Widget 树移除后，再打开地图或下一关介绍。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await _handleRpgCompletionAction(
        action,
        payload.result,
        payload.chapter,
        payload.level,
      );
    } catch (error, stackTrace) {
      debugPrint('[RPG] 结算动作失败：$error\n$stackTrace');
      if (mounted) {
        _showSnack('关卡切换失败，请返回首页后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _handlingRpgCompletion = false);
      }
    }
  }

  Future<void> _handleRpgCompletionAction(
    RpgCompletionAction action,
    RpgLevelResult result,
    int chapter,
    int level,
  ) async {
    if (!mounted) return;
    if (action == RpgCompletionAction.backToMap) {
      await _returnToRpgMap();
      return;
    }
    if (result.allCleared) {
      _showSnack('恭喜通关全部章节！');
      await _returnToRpgMap();
      return;
    }

    // 挑战失败时“下一步”实际为重试当前关，不允许越过失败关卡。
    final retry = result.stars == 0;
    final nextChapter = retry
        ? chapter
        : (result.chapterCleared ? chapter + 1 : chapter);
    final nextLevel = retry
        ? level
        : (result.chapterCleared ? 1 : level + 1);
    if (nextChapter > 3) {
      _showSnack('恭喜通关全部章节！');
      await _returnToRpgMap();
      return;
    }
    await _startRpgChallenge(nextChapter, nextLevel, popMap: false);
  }

  // v2.8.0: RPG 关卡结算 —— 计算三星、XP、徽章
  RpgLevelResult _settleRpg(PracticeResult result) {
    final chapter = result.rpgChapter;
    final level = result.rpgLevel;
    final isBoss = level == 5;

    final allCorrect = result.correct == result.total && result.total > 0;
    final duration = result.rpgStartTime != null
        ? DateTime.now().difference(result.rpgStartTime!)
        : const Duration(minutes: 5);
    final fast = duration.inSeconds <= 120;

    // 三星规则：完成=1星，2分钟内=2星，全对且2分钟内=3星
    int stars = 1;
    if (fast) stars = 2;
    if (allCorrect && fast) stars = 3;

    // XP 计算：基础每题5分 + 3星加成 + Boss加成
    final baseXp = result.correct * 5;
    final starMul = stars >= 3 ? 1.5 : 1.0;
    final bossMul = isBoss ? 2.0 : 1.0;
    final earnedXp = (baseXp * starMul * bossMul).round();

    // 更新星星（取最高）
    final levelKey = '$chapter-$level';
    final oldStars = _rpgProgress.stars[levelKey] ?? 0;
    final newStars = max(oldStars, stars);
    final newStarsMap = Map<String, int>.from(_rpgProgress.stars);
    newStarsMap[levelKey] = newStars;

    // 连续零错题
    final newStreak = allCorrect ? _rpgProgress.noErrorStreak + 1 : 0;

    // 解锁下一关
    int newChapter = _rpgProgress.currentChapter;
    int newLevel = _rpgProgress.currentLevel;
    if (chapter == _rpgProgress.currentChapter &&
        level == _rpgProgress.currentLevel) {
      if (level == 5) {
        if (chapter < 3) {
          newChapter = chapter + 1;
          newLevel = 1;
        }
      } else {
        newLevel = level + 1;
      }
    }

    // 徽章检测
    final currentBadges = Set<String>.from(_rpgProgress.unlockedBadges);
    final newBadges = <RpgBadge>[];
    RpgBadge findBadge(String id) =>
        _kRpgBadges.firstWhere((b) => b.id == id);

    // 1. 初露锋芒：首次通关
    if (_rpgProgress.stars.isEmpty && !currentBadges.contains('first_clear')) {
      newBadges.add(findBadge('first_clear'));
      currentBadges.add('first_clear');
    }
    // 2. 雷霆连击：连续3关零错
    if (newStreak >= 3 && !currentBadges.contains('no_error_3')) {
      newBadges.add(findBadge('no_error_3'));
      currentBadges.add('no_error_3');
    }
    // 3. 屠龙勇士：首次通关 Boss
    if (isBoss && !currentBadges.contains('boss_first')) {
      newBadges.add(findBadge('boss_first'));
      currentBadges.add('boss_first');
    }

    // 检查章节通关
    bool chapterCleared = level == 5;
    bool allCleared = false;
    // 4. 完美主义者：单章全三星
    if (chapterCleared) {
      bool all3 = true;
      for (var lv = 1; lv <= 5; lv++) {
        if ((newStarsMap['$chapter-$lv'] ?? 0) < 3) {
          all3 = false;
          break;
        }
      }
      if (all3 && !currentBadges.contains('chapter_3star')) {
        newBadges.add(findBadge('chapter_3star'));
        currentBadges.add('chapter_3star');
      }
    }
    // 5. 学海无涯：全部章节通关
    if (chapterCleared && chapter == 3) {
      bool allCh3 = true;
      for (var c = 1; c <= 3; c++) {
        for (var lv = 1; lv <= 5; lv++) {
          if ((newStarsMap['$c-$lv'] ?? 0) < 3) {
            allCh3 = false;
            break;
          }
        }
        if (!allCh3) break;
      }
      if (allCh3 && !currentBadges.contains('all_clear')) {
        newBadges.add(findBadge('all_clear'));
        currentBadges.add('all_clear');
        allCleared = true;
      }
    }

    // 更新进度
    _rpgProgress = RpgProgress(
      currentChapter: newChapter,
      currentLevel: newLevel,
      stars: newStarsMap,
      unlockedBadges: currentBadges,
      totalRpgXp: _rpgProgress.totalRpgXp + earnedXp,
      noErrorStreak: newStreak,
    );

    return RpgLevelResult(
      chapter: chapter,
      level: level,
      stars: stars,
      earnedXp: earnedXp,
      newBadges: newBadges,
      chapterCleared: chapterCleared,
      allCleared: allCleared,
    );
  }

  /// 错题练习：针对某资料的所有错题做复习，不走抽卡动画，不触发三倍经验。
  void _startWrongPractice(List<WrongItem> items) {
    if (items.isEmpty) {
      _showSnack('本组暂无错题');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _session = PracticeSession(
        materialName: '错题练习',
        questions: items.map((item) => item.question).toList(),
        isWrongCardChallenge: false,
        xpMultiplier: 1,
      );
    });
  }

  /// 删除单条错题（从错题本调用）
  Future<void> _deleteWrongItem(WrongItem item) async {
    setState(() {
      _wrongs.removeWhere((w) =>
          w.createdAt == item.createdAt &&
          w.question.question == item.question.question);
    });
    await _saveWrongs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除该错题'), duration: Duration(seconds: 1)),
      );
    }
  }

  /// 打开"管理资料"底部弹窗：导入文件 / 粘贴 / 示例 / 删除
  void _openMaterialManager() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final totalChars = _materials.fold<int>(
          0,
          (sum, item) => sum + item.content.length,
        );
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: kLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '管理资料',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                        ),
                      ),
                    ),
                    _TinyBadge(label: '${_materials.length} 份 · $totalChars 字'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickFile();
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('导入文件'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openPasteDialog();
                        },
                        icon: const Icon(Icons.edit_note),
                        label: const Text('粘贴文本'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD54F)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFFF57C00)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '支持格式：PDF、Word（.docx / .doc）；其他格式可使用「粘贴文本」导入。',
                          style: TextStyle(fontSize: 12, color: kInk, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _addDemoMaterial();
                  },
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('没有资料？添加一份示例'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
                if (_materials.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '已导入的资料',
                    style: TextStyle(
                      color: kMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._materials.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${m.name} · ${m.content.length} 字',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _deleteMaterial(m),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('删除'),
                          style: TextButton.styleFrom(foregroundColor: kRed),
                        ),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _dailyCheckIn() async {
    final today = _dateKey(DateTime.now());
    if (_xpProfile.lastCheckinDate == today) {
      _showSnack('今天已经打卡啦，明天继续保持');
      return;
    }
    final yesterday = _dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final streak = _xpProfile.lastCheckinDate == yesterday
        ? _xpProfile.checkinStreak + 1
        : 1;
    final earned = min(streak, 5) * 5;
    final oldLevel = _xpProfile.level;
    setState(() {
      _xpProfile = _xpProfile.copyWith(
        totalXp: _xpProfile.totalXp + earned,
        checkinStreak: streak,
        lastCheckinDate: today,
      );
    });
    await _saveXpProfile();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => XpResultDialog(
        settlement: XpSettlement(
          baseXp: earned,
          multiplier: 1,
          finalXp: earned,
          isCheckin: true,
          streak: streak,
        ),
        profile: _xpProfile,
      ),
    );
    if (mounted && _xpProfile.level > oldLevel) {
      await _showLevelUp(_xpProfile.level);
    }
  }

  XpSettlement _settleXp(PracticeResult result) {
    final baseXp = _baseXpFor(result);
    final multiplier = max(1, result.xpMultiplier);
    final finalXp = baseXp * multiplier;
    final boostActivated =
        result.isWrongCardChallenge &&
        result.total >= 5 &&
        result.correct == result.total;
    final boostExpiresAt = boostActivated
        ? DateTime.now().add(const Duration(minutes: 10))
        : _xpProfile.boostExpiresAt;
    _xpProfile = _xpProfile.copyWith(
      totalXp: _xpProfile.totalXp + finalXp,
      boostExpiresAt: boostExpiresAt,
    );
    return XpSettlement(
      baseXp: baseXp,
      multiplier: multiplier,
      finalXp: finalXp,
      boostActivated: boostActivated,
    );
  }

  int _baseXpFor(PracticeResult result) {
    var xp = 5;
    for (var i = 0; i < result.questions.length; i++) {
      final question = result.questions[i];
      final correct = i < result.correctFlags.length && result.correctFlags[i];
      if (question.type == 'fill' || question.type == 'subjective') {
        xp += 1;
      } else if (correct) {
        xp += 2;
      }
    }
    return xp;
  }

  Future<void> _completePractice(PracticeResult result) async {
    // v2.8.0: RPG 模式走独立结算路径
    if (result.gameMode == 'rpg') {
      await _completeRpgLevel(result);
      return;
    }
    final oldLevel = _xpProfile.level;
    final settlement = _settleXp(result);
    // 构建每题统计：题型 + 是否正确 + 选项字母 + 知识点
    final stats = <QuestionStat>[];
    for (var i = 0; i < result.questions.length; i++) {
      final q = result.questions[i];
      final isCorrect =
          i < result.correctFlags.length && result.correctFlags[i];
      String letter = '';
      if (q.type == 'choice' || q.type == 'multi_choice') {
        final ans = q.answer?.toString().trim() ?? '';
        if (ans.isNotEmpty) letter = ans[0].toUpperCase();
      }
      // 知识点近似：取题干前 12 个字符作为分组依据（无显式知识点标注时的兜底）
      final kp = q.question.length > 12
          ? q.question.substring(0, 12).replaceAll(RegExp(r'[\s\n]+'), ' ').trim()
          : q.question.trim();
      stats.add(QuestionStat(
        type: q.type,
        isCorrect: isCorrect,
        answerLetter: letter,
        knowledgePoint: kp.isEmpty ? '综合' : kp,
      ));
    }
    setState(() {
      _records.insert(
        0,
        PracticeRecord(
          materialName: result.materialName,
          total: result.total,
          correct: result.correct,
          createdAt: DateTime.now(),
          xpEarned: settlement.finalXp,
          isWrongCardChallenge: result.isWrongCardChallenge,
          questionStats: stats,
        ),
      );
      _wrongs = mergeWrongItems(
        _wrongs,
        result.wrongs,
        resolvedQuestions:
            result.isWrongCardChallenge ? result.questions : const [],
      );
      // v2.7.3: 追加到每日练习趋势日志（独立持久化，删除历史记录不影响趋势）
      final todayKey = _dateKey(DateTime.now());
      _practiceLog[todayKey] = (_practiceLog[todayKey] ?? 0) + result.total;
      _session = null;
      _tab = 4;
    });
    await _saveRecords();
    await _saveWrongs();
    await _saveXpProfile();
    await _savePracticeLog();
    _syncBoostTicker();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PracticeCompleteOverlay(
        settlement: settlement,
        profile: _xpProfile,
        correct: result.correct,
        total: result.total,
        isWrongCardChallenge: result.isWrongCardChallenge,
      ),
    );
    if (mounted && _xpProfile.level > oldLevel) {
      await _showLevelUp(_xpProfile.level);
    }
  }

  // v2.8.0: RPG 关卡完成结算
  Future<void> _completeRpgLevel(PracticeResult result) async {
    final rpgResult = _settleRpg(result);
    // 仍记录到练习历史（含每题统计）
    final stats = <QuestionStat>[];
    for (var i = 0; i < result.questions.length; i++) {
      final q = result.questions[i];
      final isCorrect =
          i < result.correctFlags.length && result.correctFlags[i];
      final kp = q.question.length > 12
          ? q.question.substring(0, 12).replaceAll(RegExp(r'[\s\n]+'), ' ').trim()
          : q.question.trim();
      stats.add(QuestionStat(
        type: q.type,
        isCorrect: isCorrect,
        answerLetter: '',
        knowledgePoint: kp.isEmpty ? 'RPG' : kp,
      ));
    }
    setState(() {
      _records.insert(
        0,
        PracticeRecord(
          materialName: result.materialName,
          total: result.total,
          correct: result.correct,
          createdAt: DateTime.now(),
          xpEarned: rpgResult.earnedXp,
          isWrongCardChallenge: false,
          questionStats: stats,
        ),
      );
      // RPG 错题也归入错题本
      _wrongs.insertAll(0, result.wrongs);
      final todayKey = _dateKey(DateTime.now());
      _practiceLog[todayKey] = (_practiceLog[todayKey] ?? 0) + result.total;
      _session = null;
    });
    await _saveRecords();
    await _saveWrongs();
    await _savePracticeLog();
    await _saveRpgProgress();
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() {
      _pendingRpgCompletion = RpgCompletionPayload(
        result: rpgResult,
        chapter: result.rpgChapter,
        level: result.rpgLevel,
      );
    });
  }

  Future<void> _showLevelUp(int newLevel) async {
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => LevelUpOverlay(
        newLevel: newLevel,
        title: _levelTitle(newLevel),
      ),
    );
  }

  Widget _buildParsingOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '正在解析${_parseFileName ?? ''}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '大文件解析可能需要数秒，请稍候...',
                    style: TextStyle(fontSize: 12, color: kMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: _SplashLoadingView());
    }
    // v2.9.0: RPG 闯关用 MiniGamePage 替代 PracticeScreen
    final miniSession = _miniGameSession;
    if (miniSession != null) {
      return MiniGamePage(
        session: miniSession,
        onExit: () => setState(() => _miniGameSession = null),
        onComplete: _completeMiniGameLevel,
      );
    }
    final session = _session;
    if (session != null) {
      return PracticeScreen(
        session: session,
        onExit: () => setState(() => _session = null),
        onComplete: _completePractice,
      );
    }
    // v2.9.0: RPG 出题中显示游戏化加载页（替代无声跳回首页）
    if (_rpgGenerating && _session == null) {
      return RpgLoadingView(subject: _rpgSubject);
    }

    final pages = [
      HomePage(
        materials: _materials,
        records: _records,
        wrongs: _wrongs,
        xpProfile: _xpProfile,
        configReady: _config.ready,
        onPickFile: _pickFile,
        onPaste: _openPasteDialog,
        onDemo: _addDemoMaterial,
        onGenerate: (material) {
          setState(() {
            _selectedMaterial = material;
            _tab = 1;
          });
        },
        onGoGenerate: () => setState(() => _tab = 1),
        onGoWrong: () => setState(() => _tab = 3),
        onDrawCards: _startWrongCardChallenge,
        onCheckIn: _dailyCheckIn,
        onOpenConfig: _openConfigPage,
        onRpgChallenge: _openRpgMap,
      ),
      GeneratePage(
        materials: _materials,
        selectedMaterial: _selectedMaterial,
        selectedTypes: _selectedTypes,
        questionCount: _questionCount,
        audience: _audience,
        audiences: _audiences,
        generating: _generating,
        enableRichContent: _enableRichContent,
        enableListening: _enableListening,
        onMaterialChanged: (material) {
          HapticFeedback.selectionClick();
          setState(() => _selectedMaterial = material);
        },
        onToggleType: (type) {
          HapticFeedback.selectionClick();
          setState(() {
            if (_selectedTypes.contains(type)) {
              if (_selectedTypes.length == 1) {
                _showSnack('请至少选择一种题型');
              } else {
                _selectedTypes.remove(type);
              }
            } else {
              _selectedTypes.add(type);
            }
          });
        },
        onCountChanged: (count) {
          HapticFeedback.selectionClick();
          setState(() => _questionCount = count);
        },
        onAudienceChanged: (value) {
          HapticFeedback.selectionClick();
          setState(() => _audience = value);
        },
        onToggleRichContent: (v) async {
          HapticFeedback.selectionClick();
          setState(() => _enableRichContent = v);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enableRichKey, v);
        },
        onToggleListening: (v) async {
          HapticFeedback.selectionClick();
          setState(() => _enableListening = v);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enableListeningKey, v);
        },
        onGenerate: _generateQuestions,
        onPickFile: _pickFile,
        onPaste: _openPasteDialog,
        onDemo: _addDemoMaterial,
        onDeleteMaterial: _deleteMaterial,
        onManageMaterials: _openMaterialManager,
      ),
      PaperPage(
        materials: _materials,
        papers: _papers,
        generating: _paperGenerating,
        configReady: _config.ready,
        enableRichContent: _enableRichContent,
        enableListening: _enableListening,
        onToggleRichContent: (v) async {
          HapticFeedback.selectionClick();
          setState(() => _enableRichContent = v);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enableRichKey, v);
        },
        onToggleListening: (v) async {
          HapticFeedback.selectionClick();
          setState(() => _enableListening = v);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enableListeningKey, v);
        },
        onGenerate: _generatePaper,
        onView: _openPaperViewer,
        onDelete: (id, name) => _deletePaper(id, name: name),
        onDownload: _downloadPaper,
        onDownloadAnswer: _downloadPaperAnswer,
        onDownloadAudio: _downloadPaperAudio,
        onOpenConfig: _openConfigPage,
        onDeletePapers: (toDelete) async {
          HapticFeedback.mediumImpact();
          if (toDelete.isEmpty) return;
          setState(() {
            for (final p in toDelete) {
              _papers.removeWhere((x) => x.id == p.id);
            }
          });
          await _savePapers();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已删除 ${toDelete.length} 份试卷'), duration: const Duration(seconds: 1)),
            );
          }
        },
      ),
      WrongBookPage(
        wrongs: _wrongs,
        xpProfile: _xpProfile,
        onDrawCards: _startWrongCardChallenge,
        onPracticeGroup: _startWrongPractice,
        onDeleteWrong: _deleteWrongItem,
        onDeleteWrongs: (toDelete) async {
          HapticFeedback.mediumImpact();
          if (toDelete.isEmpty) return;
          setState(() {
            for (final w in toDelete) {
              _wrongs.removeWhere((x) =>
                  x.createdAt == w.createdAt &&
                  x.question.question == w.question.question);
            }
          });
          await _saveWrongs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已删除 ${toDelete.length} 道错题'), duration: const Duration(seconds: 1)),
            );
          }
        },
      ),
      MePage(
        records: _records,
        wrongs: _wrongs,
        xpProfile: _xpProfile,
        configReady: _config.ready,
        onCheckIn: _dailyCheckIn,
        onOpenConfig: _openConfigPage,
        onOpenFeedback: _openFeedback,
        practiceLog: _practiceLog,
        onClearRecords: () async {
          HapticFeedback.mediumImpact();
          setState(() => _records = []);
          await _saveRecords();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已清空全部历史记录'), duration: Duration(seconds: 1)),
            );
          }
        },
        onClearWrongs: () async {
          HapticFeedback.mediumImpact();
          setState(() => _wrongs = []);
          await _saveWrongs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已清空全部错题'), duration: Duration(seconds: 1)),
            );
          }
        },
        onDeleteRecord: (record) async {
          setState(() {
            _records.removeWhere((r) =>
                r.createdAt == record.createdAt &&
                r.materialName == record.materialName);
          });
          await _saveRecords();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已删除该记录'), duration: Duration(seconds: 1)),
            );
          }
        },
        onDeleteWrong: (item) async {
          setState(() {
            _wrongs.removeWhere((w) =>
                w.createdAt == item.createdAt &&
                w.question.question == item.question.question);
          });
          await _saveWrongs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已删除该错题'), duration: Duration(seconds: 1)),
            );
          }
        },
        onDeleteRecords: (toDelete) async {
          HapticFeedback.mediumImpact();
          if (toDelete.isEmpty) return;
          setState(() {
            for (final r in toDelete) {
              _records.removeWhere((x) =>
                  x.createdAt == r.createdAt && x.materialName == r.materialName);
            }
          });
          await _saveRecords();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已删除 ${toDelete.length} 条历史记录'), duration: const Duration(seconds: 1)),
            );
          }
        },
        onDeleteWrongs: (toDelete) async {
          HapticFeedback.mediumImpact();
          if (toDelete.isEmpty) return;
          setState(() {
            for (final w in toDelete) {
              _wrongs.removeWhere((x) =>
                  x.createdAt == w.createdAt &&
                  x.question.question == w.question.question);
            }
          });
          await _saveWrongs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已删除 ${toDelete.length} 道错题'), duration: const Duration(seconds: 1)),
            );
          }
        },
      ),
    ];

    final mainScaffold = Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FloatingQuestionsBackground(),
          ),
          SafeArea(
            // v2.7.2: 改用 IndexedStack 保持所有页面常驻，避免切换时重建卡顿
            child: IndexedStack(
              index: _tab,
              children: pages,
            ),
          ),
          if (_parsing) _buildParsingOverlay(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: '首页',
          ),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: '出题'),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            label: '试卷',
          ),
          NavigationDestination(icon: Icon(Icons.book_outlined), label: '错题'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: '我的'),
        ],
      ),
    );
    final pendingCompletion = _pendingRpgCompletion;
    if (pendingCompletion == null) return mainScaffold;
    return Stack(
      fit: StackFit.expand,
      children: [
        mainScaffold,
        RpgLevelCompleteOverlay(
          result: pendingCompletion.result,
          onAction: _consumeRpgCompletionAction,
        ),
      ],
    );
  }
}

class OnboardingGuide extends StatefulWidget {
  const OnboardingGuide({super.key});

  @override
  State<OnboardingGuide> createState() => _OnboardingGuideState();
}

class _OnboardingGuideState extends State<OnboardingGuide> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _steps = [
    _GuideStep(
      icon: Icons.folder_copy_outlined,
      title: '先导入资料',
      body: '在“资料”页上传 PDF、Word、TXT，或粘贴文本。资料会保存在当前手机里，后续出题都从这里开始。',
      tip: '如果是第一次试用，可以点“示例资料”先跑通流程。',
    ),
    _GuideStep(
      icon: Icons.auto_awesome,
      title: '再生成题目',
      body: '在“出题”页选择资料、题型、目标群体和题目数量。题型可以多选，AI 会根据资料自动生成练习题。',
      tip: '生成前请先完成 API 配置，否则模型无法工作。',
    ),
    _GuideStep(
      icon: Icons.book_outlined,
      title: '错题会自动收集',
      body: '答题结束后，答错的题会进入“错题”页，方便你后续复习和针对性训练。',
      tip: '清空和删除这类危险操作后续都会加二次确认，避免误触。',
    ),
    _GuideStep(
      icon: Icons.key_rounded,
      title: '最后配置 API Key',
      body: 'AI题库不自带模型账号。你需要在 DeepSeek、Qwen、智谱、小米 MiMo、Kimi 等平台创建自己的 API Key。',
      tip: '不知道 Key 去哪里拿？官网的“API 配置指南”已经放好入口：aichuti.ccwu.cc/#apikey',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => Navigator.of(context).pop(true);

  Future<void> _next() async {
    if (_index == _steps.length - 1) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    await _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Row(
                children: [
                  const _LogoMark(size: 44),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '欢迎使用 AI题库',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: kInk,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text('一分钟了解每个页面能做什么', style: TextStyle(color: kMuted)),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _finish, child: const Text('跳过')),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _index = value);
                  },
                  itemBuilder: (context, index) =>
                      _GuideStepCard(step: _steps[index]),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _index ? kBlue : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(
                    _index == _steps.length - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(_index == _steps.length - 1 ? '开始使用' : '下一步'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.tip,
  });

  final IconData icon;
  final String title;
  final String body;
  final String tip;
}

class _GuideStepCard extends StatelessWidget {
  const _GuideStepCard({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(step.icon, color: kBlue, size: 36),
          ),
          const SizedBox(height: 26),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            step.body,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.75,
              color: kMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.tip,
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      height: 1.55,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kBlue,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(Icons.school_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.materials,
    required this.records,
    required this.wrongs,
    required this.xpProfile,
    required this.configReady,
    required this.onPickFile,
    required this.onPaste,
    required this.onDemo,
    required this.onGenerate,
    required this.onGoGenerate,
    required this.onGoWrong,
    required this.onDrawCards,
    required this.onCheckIn,
    required this.onOpenConfig,
    required this.onRpgChallenge,
  });

  final List<StudyMaterial> materials;
  final List<PracticeRecord> records;
  final List<WrongItem> wrongs;
  final XpProfile xpProfile;
  final bool configReady;
  final VoidCallback onPickFile;
  final VoidCallback onPaste;
  final VoidCallback onDemo;
  final ValueChanged<StudyMaterial> onGenerate;
  final VoidCallback onGoGenerate;
  final VoidCallback onGoWrong;
  final VoidCallback onDrawCards;
  final VoidCallback onCheckIn;
  final VoidCallback onOpenConfig;
  final VoidCallback onRpgChallenge;

  @override
  Widget build(BuildContext context) {
    final today = _dateKey(DateTime.now());
    final todayXp = records
        .where((record) => _dateKey(record.createdAt) == today)
        .fold<int>(0, (sum, record) => sum + record.xpEarned);
    final totalDone = records.fold<int>(0, (sum, record) => sum + record.total);
    final correct = records.fold<int>(0, (sum, record) => sum + record.correct);
    final accuracy = totalDone == 0 ? 0 : (correct / totalDone * 100).round();
    final latestRecord = records.isEmpty ? null : records.first;
    final latestMaterials = materials.take(3).toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _StaggeredAppear(
          child: _HomeHeroCard(
            xpProfile: xpProfile,
            configReady: configReady,
            onOpenConfig: onOpenConfig,
          ),
        ),
        const SizedBox(height: 16),
        _StaggeredAppear(
          delay: const Duration(milliseconds: 80),
          child: _LearningStatusCard(
            todayXp: todayXp,
            totalDone: totalDone,
            accuracy: accuracy,
            wrongCount: wrongs.length,
            xpProfile: xpProfile,
            onCheckIn: onCheckIn,
          ),
        ),
        const SizedBox(height: 16),
        _StaggeredAppear(
          delay: const Duration(milliseconds: 160),
          child: _HomeActionGrid(
            onPickFile: onPickFile,
            onPaste: onPaste,
            onGenerate: onGoGenerate,
            onWrongCards: onGoWrong,
            onRpgChallenge: onRpgChallenge,
          ),
        ),
        const SizedBox(height: 16),
        _StaggeredAppear(
          delay: const Duration(milliseconds: 240),
          child: _WrongCardEntry(
            wrongCount: wrongs.length,
            xpProfile: xpProfile,
            onTap: onDrawCards,
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: '最近资料',
          subtitle: materials.isEmpty ? '等待导入' : '${materials.length} 份',
        ),
        const SizedBox(height: 10),
        if (latestMaterials.isEmpty)
          _EmptyCard(
            icon: Icons.upload_file_rounded,
            title: '先导入一份资料',
            subtitle: '支持 PDF、Word、TXT、Markdown 等资料。也可以先添加示例资料体验。',
            action: OutlinedButton.icon(
              onPressed: onDemo,
              icon: const Icon(Icons.science_outlined),
              label: const Text('添加示例资料'),
            ),
          )
        else
          ...latestMaterials.map(
            (material) => _RecentMaterialTile(
              material: material,
              onGenerate: () => onGenerate(material),
            ),
          ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: '最近练习',
          subtitle: latestRecord == null
              ? '暂无记录'
              : _dateText(latestRecord.createdAt),
        ),
        const SizedBox(height: 10),
        if (latestRecord == null)
          const _EmptyCard(
            icon: Icons.history_rounded,
            title: '还没有练习记录',
            subtitle: '生成一组题并完成练习后，这里会显示最近一次结果。',
          )
        else
          _PracticeRecordTile(record: latestRecord),
      ],
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({
    required this.xpProfile,
    required this.configReady,
    required this.onOpenConfig,
  });

  final XpProfile xpProfile;
  final bool configReady;
  final VoidCallback onOpenConfig;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '早上好，同学' : (hour < 18 ? '下午好，同学' : '晚上好，同学');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -36,
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 10,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LogoMark(size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          '今天也来巩固一点知识吧',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _GlassStatusPill(
                      icon: Icons.bolt_rounded,
                      label: _levelTitle(xpProfile.level),
                      value: 'Lv.${xpProfile.level} · ${xpProfile.totalXp} XP',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GlassStatusPill(
                      icon: Icons.local_fire_department_rounded,
                      label: '连续打卡',
                      value: '${xpProfile.checkinStreak} 天',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _GlassStatusPill(
                      icon: configReady
                          ? Icons.check_circle_rounded
                          : Icons.key_rounded,
                      label: 'API',
                      value: configReady ? '已配置' : '待配置',
                    ),
                  ),
                  if (!configReady) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onOpenConfig,
                        icon: const Icon(Icons.key_rounded, size: 18),
                        label: const Text('配置 Key'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassStatusPill extends StatelessWidget {
  const _GlassStatusPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _AnimatedValue(
                value: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearningStatusCard extends StatelessWidget {
  const _LearningStatusCard({
    required this.todayXp,
    required this.totalDone,
    required this.accuracy,
    required this.wrongCount,
    required this.xpProfile,
    required this.onCheckIn,
  });

  final int todayXp;
  final int totalDone;
  final int accuracy;
  final int wrongCount;
  final XpProfile xpProfile;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final checkedIn = xpProfile.lastCheckinDate == _dateKey(DateTime.now());
    final boostActive = xpProfile.isBoostActive();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '今日学习状态',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: checkedIn ? null : onCheckIn,
                icon: Icon(
                  checkedIn ? Icons.check_rounded : Icons.event_available,
                ),
                label: Text(checkedIn ? '今日已打卡' : '立即打卡'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniMetric(
                icon: Icons.bolt_rounded,
                label: '今日 XP',
                value: '+$todayXp',
              ),
              const SizedBox(width: 10),
              _MiniMetric(
                icon: Icons.task_alt_rounded,
                label: '累计做题',
                value: '$totalDone',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniMetric(
                icon: Icons.speed_rounded,
                label: '正确率',
                value: '$accuracy%',
              ),
              const SizedBox(width: 10),
              _MiniMetric(
                icon: Icons.bookmark_remove_outlined,
                label: '错题',
                value: '$wrongCount',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: boostActive
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: boostActive ? const Color(0xFFFDBA74) : kLine,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  boostActive
                      ? Icons.local_fire_department_rounded
                      : Icons.style_outlined,
                  color: boostActive ? const Color(0xFFF97316) : kMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    boostActive
                        ? '三倍经验进行中 · 剩余 ${_durationText(xpProfile.boostRemaining())}'
                        : '错题抽卡 5 题全对，可开启 10 分钟三倍经验',
                    style: TextStyle(
                      color: boostActive ? const Color(0xFF9A3412) : kMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionGrid extends StatelessWidget {
  const _HomeActionGrid({
    required this.onPickFile,
    required this.onPaste,
    required this.onGenerate,
    required this.onWrongCards,
    required this.onRpgChallenge,
  });

  final VoidCallback onPickFile;
  final VoidCallback onPaste;
  final VoidCallback onGenerate;
  final VoidCallback onWrongCards;
  final VoidCallback onRpgChallenge;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _HomeActionCard(
          icon: Icons.upload_file_rounded,
          title: '上传资料',
          subtitle: 'PDF / Word / TXT',
          onTap: onPickFile,
        ),
        _HomeActionCard(
          icon: Icons.edit_note_rounded,
          title: '粘贴资料',
          subtitle: '快速录入文本',
          onTap: onPaste,
          color: const Color(0xFF10B981),
        ),
        _HomeActionCard(
          icon: Icons.auto_awesome_rounded,
          title: '开始出题',
          subtitle: '按步骤生成练习',
          onTap: onGenerate,
          color: const Color(0xFF7C3AED),
        ),
        _HomeActionCard(
          icon: Icons.style_rounded,
          title: '错题抽卡',
          subtitle: '随机复习薄弱点',
          onTap: onWrongCards,
          color: const Color(0xFFF97316),
        ),
        _HomeActionCard(
          icon: Icons.flag_rounded,
          title: '闯关挑战',
          subtitle: 'RPG 闯关赢徽章',
          onTap: onRpgChallenge,
          color: const Color(0xFFEC4899),
        ),
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = kBlue,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kLine),
          boxShadow: const [
            BoxShadow(
              color: Color(0x070F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentMaterialTile extends StatelessWidget {
  const _RecentMaterialTile({required this.material, required this.onGenerate});

  final StudyMaterial material;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.description_rounded, color: kBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fileTypeLabel(material.name)} · ${material.content.length} 字 · ${_dateText(material.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: onGenerate, child: const Text('出题')),
        ],
      ),
    );
  }
}

class GeneratePage extends StatelessWidget {
  const GeneratePage({
    super.key,
    required this.materials,
    required this.selectedMaterial,
    required this.selectedTypes,
    required this.questionCount,
    required this.audience,
    required this.audiences,
    required this.generating,
    required this.enableRichContent,
    required this.enableListening,
    required this.onMaterialChanged,
    required this.onToggleType,
    required this.onCountChanged,
    required this.onAudienceChanged,
    required this.onToggleRichContent,
    required this.onToggleListening,
    required this.onGenerate,
    required this.onPickFile,
    required this.onPaste,
    required this.onDemo,
    required this.onDeleteMaterial,
    required this.onManageMaterials,
  });

  final List<StudyMaterial> materials;
  final StudyMaterial? selectedMaterial;
  final Set<String> selectedTypes;
  final int questionCount;
  final String audience;
  final List<String> audiences;
  final bool generating;
  final bool enableRichContent;
  final bool enableListening;
  final ValueChanged<StudyMaterial?> onMaterialChanged;
  final ValueChanged<String> onToggleType;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<String> onAudienceChanged;
  final ValueChanged<bool> onToggleRichContent;
  final ValueChanged<bool> onToggleListening;
  final VoidCallback onGenerate;
  final VoidCallback onPickFile;
  final VoidCallback onPaste;
  final VoidCallback onDemo;
  final ValueChanged<StudyMaterial> onDeleteMaterial;
  /// 打开"管理资料"底部弹窗（导入文件 / 粘贴 / 示例 / 删除）
  final VoidCallback onManageMaterials;

  @override
  Widget build(BuildContext context) {
    final material = selectedMaterial;
    final activeMaterial =
        material ?? (materials.isEmpty ? null : materials.first);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _PageTitle(title: '出题练习', subtitle: '选择资料、题型和数量，AI 将在手机端直接生成练习。'),
        const SizedBox(height: 16),
        const _FlowStepHeader(
          step: '01',
          title: '选择资料',
          subtitle: '点击下方管理资料可导入或删除。',
        ),
        const SizedBox(height: 10),
        if (materials.isEmpty) ...[
          const _EmptyCard(
            icon: Icons.upload_file,
            title: '请先添加资料',
            subtitle: '点击“管理资料”导入文件、粘贴文本或添加示例。',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onManageMaterials,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('管理资料'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: kBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '当前练习资料',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: kInk,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activeMaterial == null
                                ? '未选择资料'
                                : '${activeMaterial.content.length} 字 · ${_dateText(activeMaterial.createdAt)}',
                            style: const TextStyle(
                              color: kMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<StudyMaterial>(
                  initialValue: activeMaterial,
                  items: materials
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onMaterialChanged,
                  decoration: InputDecoration(
                    labelText: '切换资料',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onManageMaterials,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('管理资料（导入 / 删除）'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBlue,
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _FlowStepHeader(
            step: '02',
            title: '选择题型',
            subtitle: '支持多选混合出题。',
          ),
          const SizedBox(height: 10),
          const _SectionHeader(title: '题型选择', subtitle: '可多选混合出题'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children:
                const [
                  _TypeMeta('choice', '单选题', '四选一'),
                  _TypeMeta('multi_choice', '多选题', '多选多'),
                  _TypeMeta('true_false', '判断题', '对 / 错'),
                  _TypeMeta('fill', '填空题', '手动输入'),
                  _TypeMeta('subjective', '主观题', '简答 / 论述'),
                ].map((meta) {
                  final selected = selectedTypes.contains(meta.type);
                  return InkWell(
                    onTap: () => onToggleType(meta.type),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFEFF6FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? kBlue : kLine,
                          width: selected ? 2 : 1.4,
                        ),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Color(0x1A2563EB),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (selected)
                            const Positioned(
                              right: 12,
                              top: 10,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: kBlue,
                                child: Icon(
                                  Icons.check,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _typeIcon(meta.type),
                                  color: selected ? kBlue : kMuted,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  meta.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: kInk,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  meta.subtitle,
                                  style: const TextStyle(color: kMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 22),
          const _FlowStepHeader(
            step: '03',
            title: '设置练习参数',
            subtitle: '选择目标群体和本轮题量。',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  items: audiences
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onAudienceChanged(value);
                  },
                  decoration: InputDecoration(
                    labelText: '目标群体',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '题目数量',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: kMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kLine),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        onPressed: questionCount <= 1
                            ? null
                            : () => onCountChanged(questionCount - 1),
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        '$questionCount',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: questionCount >= 20
                            ? null
                            : () => onCountChanged(questionCount + 1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 10, 15, 20].map((count) {
                    final selected = questionCount == count;
                    return ChoiceChip(
                      label: Text('$count 题'),
                      selected: selected,
                      onSelected: (_) => onCountChanged(count),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                const Text(
                  '范围 1—20 题；题型多选时会混合生成。',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: enableRichContent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: enableRichContent ? const Color(0xFF93C5FD) : kLine,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: enableRichContent
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          color: enableRichContent ? Colors.white : kMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '启用图表/公式渲染',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: kInk,
                              ),
                            ),
                            Text(
                              enableRichContent ? '已开启：图表题约占总题数 25%（保持在 20%-30%）' : '关闭：纯文字题目，生成更快',
                              style: const TextStyle(color: kMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enableRichContent,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          onToggleRichContent(v);
                        },
                        activeThumbColor: kBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 启用音频题（英语听力）开关
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: enableListening ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: enableListening ? const Color(0xFF86EFAC) : kLine,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: enableListening
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.headphones_rounded,
                          color: enableListening ? Colors.white : kMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '启用音频题（英语听力）',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: kInk,
                              ),
                            ),
                            Text(
                              enableListening ? '已开启：听力题约占总题数 25%（保持在 20%-30%）' : '关闭：纯文字题，无听力音频',
                              style: const TextStyle(color: kMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enableListening,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          onToggleListening(v);
                        },
                        activeThumbColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _FlowStepHeader(
            step: '04',
            title: '生成题目',
            subtitle: '确认设置后，AI 会生成本轮练习。',
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: generating ? null : onGenerate,
            icon: generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(generating ? 'AI 正在出题...' : '生成题目'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeMeta {
  const _TypeMeta(this.type, this.title, this.subtitle);

  final String type;
  final String title;
  final String subtitle;
}

class PracticeSession {
  const PracticeSession({
    required this.materialName,
    required this.questions,
    this.sourceWrongs = const [],
    this.isWrongCardChallenge = false,
    this.xpMultiplier = 1,
    this.gameMode = 'normal',         // normal / wrongcard / rpg
    this.rpgChapter = 0,              // RPG 章节（仅 rpg 模式）
    this.rpgLevel = 0,                // RPG 关卡（仅 rpg 模式）
    this.rpgStartTime,                // RPG 开始时间（用于三星计时）
  });

  final String materialName;
  final List<AiQuestion> questions;
  final List<WrongItem> sourceWrongs;
  final bool isWrongCardChallenge;
  final int xpMultiplier;
  final String gameMode;
  final int rpgChapter;
  final int rpgLevel;
  final DateTime? rpgStartTime;
}

class PracticeResult {
  PracticeResult({
    required this.materialName,
    required this.total,
    required this.correct,
    required this.wrongs,
    required this.questions,
    required this.correctFlags,
    required this.isWrongCardChallenge,
    required this.xpMultiplier,
    this.gameMode = 'normal',
    this.rpgChapter = 0,
    this.rpgLevel = 0,
    this.rpgStartTime,
  });

  final String materialName;
  final int total;
  final int correct;
  final List<WrongItem> wrongs;
  final List<AiQuestion> questions;
  final List<bool> correctFlags;
  final bool isWrongCardChallenge;
  final int xpMultiplier;
  final String gameMode;
  final int rpgChapter;
  final int rpgLevel;
  final DateTime? rpgStartTime;
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.session,
    required this.onExit,
    required this.onComplete,
  });

  final PracticeSession session;
  final VoidCallback onExit;
  final ValueChanged<PracticeResult> onComplete;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final TextEditingController _answerCtrl = TextEditingController();
  final Set<int> _selected = {};
  final List<WrongItem> _wrongs = [];
  final List<bool> _correctFlags = [];
  int _index = 0;
  int _correct = 0;
  bool _answered = false;
  bool? _lastCorrect;
  String _userAnswer = '';

  AiQuestion get _question => widget.session.questions[_index];

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _question;
    final answer = _currentAnswer();
    if (answer.trim().isEmpty) {
      _snack('请先选择或输入答案');
      return;
    }
    final correct = _isCorrect(question, answer);
    setState(() {
      _answered = true;
      _lastCorrect = correct;
      _userAnswer = answer;
      if (correct) {
        _correct++;
      } else {
        WrongItem? source;
        final key = wrongQuestionKey(question);
        for (final item in widget.session.sourceWrongs) {
          if (wrongQuestionKey(item.question) == key) {
            source = item;
            break;
          }
        }
        _wrongs.add(
          WrongItem(
            materialName: source?.materialName ?? widget.session.materialName,
            question: question,
            userAnswer: answer,
            createdAt: DateTime.now(),
          ),
        );
      }
      _correctFlags.add(correct);
    });
    // 全屏打勾/打叉评判动画
    if (mounted) {
      HapticFeedback.heavyImpact();
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => JudgeOverlay(correct: correct),
      );
    }
  }

  void _next() {
    if (_index >= widget.session.questions.length - 1) {
      widget.onComplete(
        PracticeResult(
          materialName: widget.session.materialName,
          total: widget.session.questions.length,
          correct: _correct,
          wrongs: _wrongs,
          questions: widget.session.questions,
          correctFlags: _correctFlags,
          isWrongCardChallenge: widget.session.isWrongCardChallenge,
          xpMultiplier: widget.session.xpMultiplier,
          gameMode: widget.session.gameMode,
          rpgChapter: widget.session.rpgChapter,
          rpgLevel: widget.session.rpgLevel,
          rpgStartTime: widget.session.rpgStartTime,
        ),
      );
      return;
    }
    setState(() {
      _index++;
      _answered = false;
      _lastCorrect = null;
      _userAnswer = '';
      _selected.clear();
      _answerCtrl.clear();
    });
  }

  String _currentAnswer() {
    if (_question.type == 'fill' || _question.type == 'subjective') {
      return _answerCtrl.text;
    }
    if (_question.type == 'multi_choice') {
      final letters = _selected.map((index) => _letter(index)).toList()..sort();
      return letters.join(',');
    }
    if (_selected.isEmpty) return '';
    if (_question.type == 'true_false') {
      return _selected.first == 0 ? '正确' : '错误';
    }
    return _letter(_selected.first);
  }

  bool _isCorrect(AiQuestion question, String answer) {
    if (question.type == 'subjective') {
      return answer.trim().length >= 8;
    }
    if (question.type == 'multi_choice') {
      final expected = _answerSet(question.answer);
      final actual = answer
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      return expected.length == actual.length && expected.containsAll(actual);
    }
    final expected = _answerString(question.answer);
    if (question.type == 'fill') {
      final a = answer.trim().toLowerCase();
      final e = expected.trim().toLowerCase();
      return a == e || (e.length >= 2 && a.contains(e));
    }
    return answer.trim().toUpperCase() == expected.trim().toUpperCase() ||
        answer.trim() == expected.trim();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;
    final progress = (_index + 1) / widget.session.questions.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_index + 1}/${widget.session.questions.length} · ${question.label}',
        ),
        leading: IconButton(
          onPressed: widget.onExit,
          icon: const Icon(Icons.close),
        ),
      ),
      body: Stack(children: [
        const Positioned.fill(child: _FloatingQuestionsBackground()),
        SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: kLine),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(question.label),
                      backgroundColor: const Color(0xFFEFF6FF),
                      side: BorderSide.none,
                    ),
                    const SizedBox(height: 10),
                    // 图表状态指示器（debug）：帮助用户/AI 验证 rich_content 是否生效
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: question.richContent.isNotEmpty
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: question.richContent.isNotEmpty
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFED7AA),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            question.richContent.isNotEmpty
                                ? Icons.image_rounded
                                : Icons.info_outline_rounded,
                            size: 14,
                            color: question.richContent.isNotEmpty
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              question.richContent.isNotEmpty
                                  ? '图表 ${question.richContent.length} 个：${question.richContent.map((r) => r['type']).join(',')}'
                                  : '纯文字题（无图表）',
                              style: TextStyle(
                                fontSize: 11,
                                color: question.richContent.isNotEmpty
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF9A3412),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      question.question,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.55,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (question.richContent.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...question.richContent.map((rc) => RichContentBlock(
                            type: rc['type'] as String? ?? '',
                            data: (rc['data'] as Map?)?.cast<String, dynamic>() ?? const {},
                            hideListeningText: true,
                          )),
                    ],
                    const SizedBox(height: 18),
                    if (question.type == 'fill' ||
                        question.type == 'subjective')
                      TextField(
                        controller: _answerCtrl,
                        enabled: !_answered,
                        minLines: question.type == 'subjective' ? 4 : 1,
                        maxLines: question.type == 'subjective' ? 6 : 1,
                        decoration: InputDecoration(
                          labelText: question.type == 'subjective'
                              ? '输入你的简答'
                              : '输入答案',
                          border: const OutlineInputBorder(),
                        ),
                      )
                    else
                      ...List.generate(
                        question.options.length,
                        (index) => _optionTile(question, index),
                      ),
                    if (_answered) ...[
                      const SizedBox(height: 18),
                      _ResultBox(
                        correct: _lastCorrect == true,
                        answer: _answerString(question.answer),
                        explanation: question.explanation,
                        userAnswer: _userAnswer,
                        richContent: question.richContent,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _answered ? _next : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(
                _answered
                    ? (_index == widget.session.questions.length - 1
                          ? '查看结果'
                          : '下一题')
                    : '提交答案',
              ),
            ),
          ],
        ),
      ),
      ]),
    );
  }

  Widget _optionTile(AiQuestion question, int index) {
    final selected = _selected.contains(index);
    final disabled = _answered;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                setState(() {
                  if (question.type == 'multi_choice') {
                    selected ? _selected.remove(index) : _selected.add(index);
                  } else {
                    _selected
                      ..clear()
                      ..add(index);
                  }
                });
              },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? kBlue : kLine,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: selected ? kBlue : const Color(0xFFF1F5F9),
                child: Text(
                  question.type == 'true_false'
                      ? (index == 0 ? '✓' : '✕')
                      : _letter(index),
                  style: TextStyle(
                    color: selected ? Colors.white : kMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.options[index],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultBox extends StatefulWidget {
  const _ResultBox({
    required this.correct,
    required this.answer,
    required this.explanation,
    required this.userAnswer,
    this.richContent = const [],
  });

  final bool correct;
  final String answer;
  final String explanation;
  final String userAnswer;
  /// 富内容块（来自 AiQuestion.richContent）
  final List<Map<String, dynamic>> richContent;

  @override
  State<_ResultBox> createState() => _ResultBoxState();
}

class _ResultBoxState extends State<_ResultBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.correct;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: correct
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: correct ? kGreen : kRed,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      correct ? '回答正确' : '需要复习',
                      style: TextStyle(
                        color: correct ? kGreen : kRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('你的答案：${widget.userAnswer}'),
                Text('参考答案：${widget.answer}'),
                const SizedBox(height: 8),
                Text('解析：${widget.explanation}',
                    style: const TextStyle(height: 1.5)),
                if (widget.richContent.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...widget.richContent.map((rc) => RichContentBlock(
                        type: rc['type'] as String? ?? '',
                        data: (rc['data'] as Map?)?.cast<String, dynamic>() ?? const {},
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WrongBookPage extends StatefulWidget {
  const WrongBookPage({
    super.key,
    required this.wrongs,
    required this.xpProfile,
    required this.onDrawCards,
    required this.onPracticeGroup,
    required this.onDeleteWrong,
    required this.onDeleteWrongs,
  });

  final List<WrongItem> wrongs;
  final XpProfile xpProfile;
  final VoidCallback onDrawCards;
  /// 错题练习：传入某资料下的所有错题，启动针对性练习（不走抽卡动画）
  final void Function(List<WrongItem> items) onPracticeGroup;
  /// 删除单条错题
  final void Function(WrongItem item) onDeleteWrong;
  /// v2.7.3: 批量删除错题（与 MePage 统一）
  final void Function(List<WrongItem> items) onDeleteWrongs;

  @override
  State<WrongBookPage> createState() => _WrongBookPageState();
}

class _WrongBookPageState extends State<WrongBookPage> {
  String _query = '';
  bool _searchMode = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _match(WrongItem w) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    if (w.materialName.toLowerCase().contains(q)) return true;
    if (w.question.question.toLowerCase().contains(q)) return true;
    if (w.question.explanation.toLowerCase().contains(q)) return true;
    return false;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmText = '确认',
  }) async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// v2.7.3: 批量删除错题弹窗（与 MePage 统一风格，支持全选）
  Future<void> _showBatchDeleteWrongsSheet() async {
    final wrongs = widget.wrongs;
    if (wrongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('错题本已经是空的'), duration: Duration(seconds: 1)),
      );
      return;
    }
    final selected = <int>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18, 14, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '批量删除错题',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kInk),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              if (selected.length == wrongs.length) {
                                selected.clear();
                              } else {
                                selected.addAll(List.generate(wrongs.length, (i) => i));
                              }
                            });
                          },
                          child: Text(
                            selected.length == wrongs.length ? '取消全选' : '全选',
                            style: const TextStyle(color: kRed, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '已选 ${selected.length} / ${wrongs.length} 道；勾选后点击底部按钮删除。',
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: wrongs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final w = wrongs[i];
                          final checked = selected.contains(i);
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheet(() {
                                if (checked) {
                                  selected.remove(i);
                                } else {
                                  selected.add(i);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: checked ? kRed : kMuted,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          w.question.question,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: kInk),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${w.materialName} · ${_dateText(w.createdAt)}',
                                          style: const TextStyle(color: kMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(ctx, true),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(selected.isEmpty ? '未选择' : '删除选中 (${selected.length})'),
                            style: FilledButton.styleFrom(backgroundColor: kRed),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed == true && selected.isNotEmpty) {
      final toDelete = selected.map((i) => wrongs[i]).toList();
      final ok = await _confirm(
        title: '确认删除选中的错题？',
        message: '将删除 ${toDelete.length} 道错题，删除后无法恢复。',
        confirmText: '删除',
      );
      if (ok) widget.onDeleteWrongs(toDelete);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wrongs = widget.wrongs;
    final xpProfile = widget.xpProfile;
    final grouped = <String, List<WrongItem>>{};
    for (final item in wrongs) {
      if (!_match(item)) continue;
      grouped.putIfAbsent(item.materialName, () => []).add(item);
    }
    final groups = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final weakest = groups.isEmpty ? null : groups.first;
    final filteredCount = grouped.values.fold<int>(0, (s, l) => s + l.length);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(
              child: _PageTitle(title: '错题本', subtitle: '错题全部保存在手机本地。'),
            ),
            IconButton(
              tooltip: _searchMode ? '关闭检索' : '检索错题',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _searchMode = !_searchMode;
                  if (!_searchMode) {
                    _controller.clear();
                    _query = '';
                  }
                });
              },
              icon: Icon(
                _searchMode ? Icons.search_off_rounded : Icons.search_rounded,
                color: kInk,
              ),
            ),
            if (wrongs.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: '清理',
                icon: const Icon(Icons.cleaning_services_outlined, color: kInk),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'batch_wrongs',
                    child: ListTile(
                      leading: Icon(Icons.checklist_rounded, color: kRed),
                      title: Text('批量删除错题'),
                      subtitle: Text('勾选要删除的错题（可全选）'),
                      dense: true,
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'batch_wrongs') {
                    await _showBatchDeleteWrongsSheet();
                  }
                },
              ),
          ],
        ),
        if (_searchMode) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kLine),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: '搜索资料名 / 题干 / 解析',
                border: InputBorder.none,
                icon: Icon(Icons.search, size: 20, color: kMuted),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '命中 $filteredCount / ${wrongs.length} 道错题',
                style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 12),
        ] else ...[
          const SizedBox(height: 12),
        ],
        _WrongOverviewCard(
          total: wrongs.length,
          groupCount: grouped.length,
          weakestName: weakest?.key,
          weakestCount: weakest?.value.length ?? 0,
        ),
        const SizedBox(height: 14),
        _WrongCardEntry(
          wrongCount: wrongs.length,
          xpProfile: xpProfile,
          onTap: widget.onDrawCards,
        ),
        const SizedBox(height: 14),
        if (wrongs.isEmpty)
          const _EmptyCard(
            icon: Icons.check_circle_outline,
            title: '暂无错题',
            subtitle: '做题后答错的题目会自动收录到这里。',
          )
        else if (_searchMode && filteredCount == 0)
          const _EmptyCard(
            icon: Icons.search_off,
            title: '没有匹配的错题',
            subtitle: '换个关键词试试。',
          )
        else ...[
          _SectionHeader(
            title: '错题收纳',
            subtitle: _query.isEmpty
                ? '按资料自动归类（最近 3 份资料，每份前 3 题）'
                : '检索结果（$filteredCount 道）',
          ),
          const SizedBox(height: 10),
          // 检索模式下不折叠（用户主动在找），普通模式下只显示最近 3 份资料
          _CollapsibleSection(
            itemCount: groups.length,
            visibleCount: _searchMode ? groups.length : 3,
            label: '份资料',
            itemBuilder: (i) => _WrongMaterialGroup(
              group: groups[i],
              wrongVisibleCount: _searchMode ? groups[i].value.length : 3,
              onPractice: () => widget.onPracticeGroup(groups[i].value),
              onDeleteWrong: widget.onDeleteWrong,
            ),
          ),
        ],
      ],
    );
  }
}

class _WrongOverviewCard extends StatelessWidget {
  const _WrongOverviewCard({
    required this.total,
    required this.groupCount,
    required this.weakestName,
    required this.weakestCount,
  });

  final int total;
  final int groupCount;
  final String? weakestName;
  final int weakestCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MiniMetric(
                icon: Icons.error_outline_rounded,
                label: '错题',
                value: '$total 道',
              ),
              const SizedBox(width: 10),
              _MiniMetric(
                icon: Icons.inventory_2_outlined,
                label: '资料收纳',
                value: '$groupCount 组',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    weakestName == null
                        ? '暂无薄弱资料，完成练习后会自动分析。'
                        : '当前薄弱资料：$weakestName（$weakestCount 道错题）',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WrongMaterialGroup extends StatelessWidget {
  const _WrongMaterialGroup({
    required this.group,
    required this.onPractice,
    required this.onDeleteWrong,
    this.wrongVisibleCount = 3,
  });

  final MapEntry<String, List<WrongItem>> group;
  final VoidCallback onPractice;
  final void Function(WrongItem item) onDeleteWrong;
  /// 默认只显示前 N 个错题，其余折叠
  final int wrongVisibleCount;

  Future<void> _confirmDelete(BuildContext context, WrongItem item) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该错题？'),
        content: const Text('将删除该错题，删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) onDeleteWrong(item);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.folder_special_outlined, color: kBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _TinyBadge(label: '${group.value.length} 道'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onPractice,
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text(
                '练习本组错题',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: kBlue,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _CollapsibleSection(
            itemCount: group.value.length,
            visibleCount: wrongVisibleCount,
            label: '道错题',
            itemBuilder: (i) => _WrongQuestionCard(
              item: group.value[i],
              onDelete: () => _confirmDelete(context, group.value[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _WrongQuestionCard extends StatelessWidget {
  const _WrongQuestionCard({required this.item, this.onDelete});

  final WrongItem item;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey('wrong_card_${item.createdAt.toIso8601String()}_${item.question.question.hashCode}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: kRed,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          if (onDelete == null) return false;
          HapticFeedback.mediumImpact();
          onDelete!();
          return false;
        },
        child: InkWell(
          onLongPress: onDelete == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onDelete!();
                },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.question.label} · ${_dateText(item.createdAt)}',
                        style: const TextStyle(color: kMuted, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (onDelete != null)
                      const Icon(Icons.delete_outline, size: 16, color: kMuted),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.question.question,
                  style: const TextStyle(fontWeight: FontWeight.w900, height: 1.45),
                ),
                if (item.question.richContent.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...item.question.richContent.map((rc) => RepaintBoundary(
                        child: RichContentBlock(
                          type: rc['type'] as String? ?? '',
                          data: (rc['data'] as Map?)?.cast<String, dynamic>() ?? const {},
                        ),
                      )),
                ],
                const SizedBox(height: 8),
                Text('你的答案：${item.userAnswer}', style: const TextStyle(color: kRed)),
                Text(
                  '参考答案：${_answerString(item.question.answer)}',
                  style: const TextStyle(color: kGreen),
                ),
                const SizedBox(height: 6),
                Text(
                  item.question.explanation,
                  style: const TextStyle(color: kMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WrongCardEntry extends StatelessWidget {
  const _WrongCardEntry({
    required this.wrongCount,
    required this.xpProfile,
    required this.onTap,
  });

  final int wrongCount;
  final XpProfile xpProfile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canBoost = wrongCount >= 5;
    final boostText = xpProfile.isBoostActive()
        ? '三倍经验剩余 ${_durationText(xpProfile.boostRemaining())}'
        : (canBoost ? '5 题全对，开启 10 分钟三倍经验' : '错题不足 5 道也可练习，但不激活三倍经验');
    return _BouncyTap(
      onTap: onTap,
      // 无错题时仍允许点击，由上层统一给出明确提示。
      enabled: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF172554), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332563EB),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.style_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '错题抽卡',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wrongCount == 0 ? '暂无错题，先去完成一组练习吧' : boostText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ============ 试卷生成页 ============

class PaperPage extends StatefulWidget {
  const PaperPage({
    super.key,
    required this.materials,
    required this.papers,
    required this.generating,
    required this.configReady,
    required this.enableRichContent,
    required this.enableListening,
    required this.onToggleRichContent,
    required this.onToggleListening,
    required this.onGenerate,
    required this.onView,
    required this.onDelete,
    required this.onDownload,
    required this.onDownloadAnswer,
    required this.onDownloadAudio,
    required this.onOpenConfig,
    required this.onDeletePapers,
  });

  final List<StudyMaterial> materials;
  final List<Paper> papers;
  final bool generating;
  final bool configReady;
  final bool enableRichContent;
  final bool enableListening;
  final ValueChanged<bool> onToggleRichContent;
  final ValueChanged<bool> onToggleListening;
  final void Function({
    required String subject,
    required String gradeLevel,
    required int pageCount,
    required StudyMaterial material,
    required PaperScoreConfig scoreConfig,
    required PaperTemplate? template,
    String chapterRange,
    String knowledgePointSpec,
    int listeningCount,
  }) onGenerate;
  final ValueChanged<Paper> onView;
  final void Function(String id, String name) onDelete;
  final ValueChanged<Paper> onDownload;
  final ValueChanged<Paper> onDownloadAnswer;
  final ValueChanged<Paper> onDownloadAudio;
  final VoidCallback onOpenConfig;
  /// v2.7.3: 批量删除试卷（与 MePage 统一风格）
  final void Function(List<Paper> papers) onDeletePapers;

  @override
  State<PaperPage> createState() => _PaperPageState();
}

class _PaperPageState extends State<PaperPage> {
  String _subject = '数学';
  String _stage = '初中';
  String _examType = '期末';
  int _pageCount = 4;
  StudyMaterial? _material;

  // 自定义项：用户添加后会成为新的预设项，"自定义" chip 始终在末尾
  final List<String> _customSubjects = <String>[];
  final List<String> _customStages = <String>[];
  final List<String> _customExamTypes = <String>[];

  // 更多选项（折叠区）
  bool _moreExpanded = false;
  int _totalScoreMode = 0; // 0=自动, 1=100, 2=120, 3=150, 4=自定义
  int _customTotal = 100;
  int _choiceScore = 3;
  int _fillScore = 4;
  int _judgeScore = 2;
  int _subjectiveScore = 10;

  // 题量模板：0=默认（按学段+学科+类型自动）, 1=自定义题量
  int _templateMode = 0;
  int _customChoiceCount = 8;
  int _customFillCount = 5;
  int _customJudgeCount = 4;
  int _customSubjectiveCount = 3;

  // v2.7.1 按章节/知识点出题（可选，留空表示不指定）
  String _chapterRange = '';
  String _choiceKp = '';
  String _fillKp = '';
  String _judgeKp = '';
  String _subjectiveKp = '';

  // v2.7.2 试卷出题细化：每题知识点、主观题小问数与难度
  // 格式：每题一行，如"第1题: 二次函数; 第2题: 概率"
  String _perQuestionKp = '';
  // 主观题小问数与难度，如"第1题: 3问(简单-中-难); 第2题: 2问(中-难)"
  String _subjectiveSubQuestions = '';

  // 试卷听力题数量设定（0=自动按25%占比，手动值也会限制在20%-30%）
  int _listeningCount = 0;

  static const _subjects = <String>[
    '语文', '数学', '英语', '物理', '化学', '生物', '政治', '历史', '地理',
  ];
  static const _stages = <String>['小学', '初中', '高中', '成年人'];
  static const _examTypes = <String>[
    '期末', '期中', '中考模拟', '高考模拟', '周测', '小测',
  ];
  static const _pageOptions = <int>[2, 4, 6, 8];

  @override
  void initState() {
    super.initState();
    _loadLastSelection();
  }

  /// 从 SharedPreferences 读取上次选择（含自定义项）
  Future<void> _loadLastSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final sj = prefs.getString('paper.lastSubject');
    final st = prefs.getString('paper.lastStage');
    final et = prefs.getString('paper.lastExamType');
    final pc = prefs.getInt('paper.lastPageCount');
    final tm = prefs.getInt('paper.totalMode');
    final ct = prefs.getInt('paper.customTotal');
    final cs = prefs.getInt('paper.choiceScore');
    final fs = prefs.getInt('paper.fillScore');
    final js = prefs.getInt('paper.judgeScore');
    final ss = prefs.getInt('paper.subjectiveScore');
    final tplMode = prefs.getInt('paper.templateMode');
    final cChoice = prefs.getInt('paper.customChoiceCount');
    final cFill = prefs.getInt('paper.customFillCount');
    final cJudge = prefs.getInt('paper.customJudgeCount');
    final cSubj = prefs.getInt('paper.customSubjectiveCount');
    final customSj = prefs.getStringList('paper.customSubjects') ?? [];
    final customSt = prefs.getStringList('paper.customStages') ?? [];
    final customEt = prefs.getStringList('paper.customExamTypes') ?? [];
    final chapterRange = prefs.getString('paper.chapterRange') ?? '';
    final choiceKp = prefs.getString('paper.choiceKp') ?? '';
    final fillKp = prefs.getString('paper.fillKp') ?? '';
    final judgeKp = prefs.getString('paper.judgeKp') ?? '';
    final subjKp = prefs.getString('paper.subjectiveKp') ?? '';
    // v2.7.2 细化字段
    final perQKp = prefs.getString('paper.perQuestionKp') ?? '';
    final subjSub = prefs.getString('paper.subjectiveSubQ') ?? '';
    // v2.7.4 试卷听力题数量设定
    final listeningCount = prefs.getInt('paper.listeningCount') ?? 0;
    if (!mounted) return;
    setState(() {
      if (sj != null && sj.isNotEmpty) _subject = sj;
      if (st != null && st.isNotEmpty) _stage = st;
      if (et != null && et.isNotEmpty) _examType = et;
      if (pc != null) _pageCount = pc;
      if (tm != null) _totalScoreMode = tm;
      if (ct != null) _customTotal = ct;
      if (cs != null) _choiceScore = cs;
      if (fs != null) _fillScore = fs;
      if (js != null) _judgeScore = js;
      if (ss != null) _subjectiveScore = ss;
      if (tplMode != null) _templateMode = tplMode;
      if (cChoice != null) _customChoiceCount = cChoice;
      if (cFill != null) _customFillCount = cFill;
      if (cJudge != null) _customJudgeCount = cJudge;
      if (cSubj != null) _customSubjectiveCount = cSubj;
      _chapterRange = chapterRange;
      _choiceKp = choiceKp;
      _fillKp = fillKp;
      _judgeKp = judgeKp;
      _subjectiveKp = subjKp;
      _perQuestionKp = perQKp;
      _subjectiveSubQuestions = subjSub;
      _listeningCount = listeningCount;
      _customSubjects
        ..clear()
        ..addAll(customSj.whereType<String>());
      _customStages
        ..clear()
        ..addAll(customSt.whereType<String>());
      _customExamTypes
        ..clear()
        ..addAll(customEt.whereType<String>());
    });
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmText = '确认',
  }) async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// v2.7.3: 批量删除试卷弹窗（与 MePage 统一风格，支持全选）
  Future<void> _showBatchDeletePapersSheet() async {
    final papers = widget.papers;
    if (papers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有生成过试卷'), duration: Duration(seconds: 1)),
      );
      return;
    }
    final selected = <int>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18, 14, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '批量删除试卷',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kInk),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              if (selected.length == papers.length) {
                                selected.clear();
                              } else {
                                selected.addAll(List.generate(papers.length, (i) => i));
                              }
                            });
                          },
                          child: Text(
                            selected.length == papers.length ? '取消全选' : '全选',
                            style: const TextStyle(color: kBlue, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '已选 ${selected.length} / ${papers.length} 份；勾选后点击底部按钮删除。',
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: papers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = papers[i];
                          final checked = selected.contains(i);
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheet(() {
                                if (checked) {
                                  selected.remove(i);
                                } else {
                                  selected.add(i);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: checked ? kBlue : kMuted,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${p.subject} · ${p.pageCount}面 · ${p.questions.length}题',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: kInk),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${p.materialName} · ${_dateText(p.createdAt)}',
                                          style: const TextStyle(color: kMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(ctx, true),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(selected.isEmpty ? '未选择' : '删除选中 (${selected.length})'),
                            style: FilledButton.styleFrom(backgroundColor: kRed),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed == true && selected.isNotEmpty) {
      final toDelete = selected.map((i) => papers[i]).toList();
      final ok = await _confirm(
        title: '确认删除选中的试卷？',
        message: '将删除 ${toDelete.length} 份试卷，删除后无法恢复。',
        confirmText: '删除',
      );
      if (ok) widget.onDeletePapers(toDelete);
    }
  }

  /// 保存当前选择到 SharedPreferences
  Future<void> _saveLastSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paper.lastSubject', _subject);
    await prefs.setString('paper.lastStage', _stage);
    await prefs.setString('paper.lastExamType', _examType);
    await prefs.setInt('paper.lastPageCount', _pageCount);
    await prefs.setInt('paper.totalMode', _totalScoreMode);
    await prefs.setInt('paper.customTotal', _customTotal);
    await prefs.setInt('paper.choiceScore', _choiceScore);
    await prefs.setInt('paper.fillScore', _fillScore);
    await prefs.setInt('paper.judgeScore', _judgeScore);
    await prefs.setInt('paper.subjectiveScore', _subjectiveScore);
    await prefs.setInt('paper.templateMode', _templateMode);
    await prefs.setInt('paper.customChoiceCount', _customChoiceCount);
    await prefs.setInt('paper.customFillCount', _customFillCount);
    await prefs.setInt('paper.customJudgeCount', _customJudgeCount);
    await prefs.setInt('paper.customSubjectiveCount', _customSubjectiveCount);
    await prefs.setStringList('paper.customSubjects', _customSubjects);
    await prefs.setStringList('paper.customStages', _customStages);
    await prefs.setStringList('paper.customExamTypes', _customExamTypes);
    await prefs.setString('paper.chapterRange', _chapterRange);
    await prefs.setString('paper.choiceKp', _choiceKp);
    await prefs.setString('paper.fillKp', _fillKp);
    await prefs.setString('paper.judgeKp', _judgeKp);
    await prefs.setString('paper.subjectiveKp', _subjectiveKp);
    await prefs.setString('paper.perQuestionKp', _perQuestionKp);
    await prefs.setString('paper.subjectiveSubQ', _subjectiveSubQuestions);
    await prefs.setInt('paper.listeningCount', _listeningCount);
  }

  PaperScoreConfig _buildScoreConfig() => PaperScoreConfig(
        totalMode: _totalScoreMode,
        customTotal: _customTotal,
        choiceScore: _choiceScore,
        fillScore: _fillScore,
        judgeScore: _judgeScore,
        subjectiveScore: _subjectiveScore,
      );

  /// 计算当前生效的题量模板
  PaperTemplate? _buildTemplate() {
    if (_templateMode == 0) {
      // 默认模板：交给 generatePaper 内部按学段+学科+类型自动推算
      return null;
    }
    return PaperTemplate(
      choiceCount: _customChoiceCount,
      fillCount: _customFillCount,
      judgeCount: _customJudgeCount,
      subjectiveCount: _customSubjectiveCount,
    );
  }

  /// v2.7.1 拼接各题型知识点要求，留空的题型跳过
  String _buildKnowledgePointSpec() {
    final lines = <String>[];
    if (_choiceKp.trim().isNotEmpty) {
      lines.add('- 选择题：${_choiceKp.trim()}');
    }
    if (_fillKp.trim().isNotEmpty) {
      lines.add('- 填空题：${_fillKp.trim()}');
    }
    if (_judgeKp.trim().isNotEmpty) {
      lines.add('- 判断题：${_judgeKp.trim()}');
    }
    if (_subjectiveKp.trim().isNotEmpty) {
      lines.add('- 解答题：${_subjectiveKp.trim()}');
    }
    // v2.7.2 细化：每题指定知识点
    if (_perQuestionKp.trim().isNotEmpty) {
      lines.add('- 每题指定知识点（请严格按此分配）:');
      for (final line in _perQuestionKp.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) lines.add('  $trimmed');
      }
    }
    // v2.7.2 细化：主观题小问数与难度
    if (_subjectiveSubQuestions.trim().isNotEmpty) {
      lines.add('- 主观题（解答题）小问与难度要求:');
      for (final line in _subjectiveSubQuestions.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) lines.add('  $trimmed');
      }
      lines.add('  难度梯度：第1问通常为基础（简单），后续递增；每题小问数与难度严格按上方指定。');
    }
    return lines.join('\n');
  }

  /// 删除已添加的自定义项（学科/学段/类型）
  void _removeCustomItem(List<String> list, String value) {
    setState(() {
      list.removeWhere((s) => s == value);
      // 如果当前选中是被删除的项，回退到第一个预设
      if (list == _customSubjects && _subject == value) {
        _subject = _subjects.first;
      } else if (list == _customStages && _stage == value) {
        _stage = _stages.first;
      } else if (list == _customExamTypes && _examType == value) {
        _examType = _examTypes.first;
      }
    });
    _saveLastSelection();
  }

  /// 长按自定义项 → 弹窗确认删除
  Future<void> _confirmRemoveCustom({
    required String title,
    required String value,
    required List<String> list,
  }) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('确定要删除「$value」吗？\n已生成的历史试卷不会受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _removeCustomItem(list, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除「$value」'), duration: const Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _pickCustom({
    required String title,
    required String hint,
    required String preset,
    required void Function(String) onConfirm,
  }) async {
    final ctrl = TextEditingController(text: preset);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      onConfirm(result);
    }
  }

  /// 添加自定义项到列表（避免重复，最多保留 6 个自定义项）
  void _addCustomItem(List<String> list, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    list.removeWhere((s) => s == v);
    list.insert(0, v);
    while (list.length > 6) {
      list.removeLast();
    }
  }

  Future<void> _pickCustomPage() async {
    final ctrl = TextEditingController(
      text: _pageOptions.contains(_pageCount) ? '5' : _pageCount.toString(),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义页数（1-12）'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '请输入 1-12 之间的整数'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final n = int.tryParse(result);
    if (n == null || n < 1 || n > 12) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('页数必须是 1-12 之间的整数')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _pageCount = n);
  }

  Future<void> _pickCustomScore({
    required String title,
    required String hint,
    required int initial,
    required void Function(int) onConfirm,
  }) async {
    final ctrl = TextEditingController(text: initial.toString());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final n = int.tryParse(result);
    if (n == null || n <= 0 || n > 500) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 1-500 之间的正整数')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    onConfirm(n);
  }

  @override
  Widget build(BuildContext context) {
    final activeMaterial = _material ??
        (widget.materials.isEmpty ? null : widget.materials.first);

    // 历史试卷按资料分组（保留插入顺序）
    final grouped = <String, List<Paper>>{};
    for (final p in widget.papers) {
      grouped.putIfAbsent(p.materialName, () => []).add(p);
    }

    // 中文序号
    const cnNum = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十'];
    String cn(int i) => i < cnNum.length ? cnNum[i] : '${i + 1}';

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _PageTitle(
          title: '试卷生成',
          subtitle: '按期末/期中/中高考/周测等模板，生成一整套可预览、可下载的试卷。仅支持纯文本题型，涉及作图的题目暂不支持。',
        ),
        const SizedBox(height: 16),
        const _FlowStepHeader(
          step: '01',
          title: '选择资料',
          subtitle: '试卷会基于所选资料出题。',
        ),
        const SizedBox(height: 10),
        if (widget.materials.isEmpty)
          const _EmptyCard(
            icon: Icons.upload_file,
            title: '还没有资料',
            subtitle: '请先到“出题”页导入 PDF / Word / TXT 或粘贴文本。',
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kLine),
            ),
            child: DropdownButtonFormField<StudyMaterial>(
              initialValue: activeMaterial,
              decoration: const InputDecoration(
                labelText: '当前试卷资料',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
              ),
              items: widget.materials
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          '${m.name} · ${m.content.length}字',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _material = v),
            ),
          ),
        const SizedBox(height: 18),
        const _FlowStepHeader(
          step: '02',
          title: '选择学科',
          subtitle: '九科预设或自定义（适合考研、考编、职业考试等）。',
        ),
        const SizedBox(height: 10),
        _ChipGroup(
          presets: _subjects,
          customItems: _customSubjects,
          selected: _subject,
          customHint: '如：计算机、会计、行测...',
          customTitle: '自定义学科',
          onSelected: (s) {
            HapticFeedback.selectionClick();
            setState(() => _subject = s);
          },
          onPickCustom: (preset) => _pickCustom(
            title: '自定义学科',
            hint: '如：计算机、会计、行测...',
            preset: preset,
            onConfirm: (v) {
              setState(() {
                _subject = v;
                _addCustomItem(_customSubjects, v);
              });
              _saveLastSelection();
            },
          ),
          onRemoveCustom: (v) => _confirmRemoveCustom(
            title: '删除自定义学科',
            value: v,
            list: _customSubjects,
          ),
        ),
        const SizedBox(height: 18),
        const _FlowStepHeader(
          step: '03',
          title: '选择学段',
          subtitle: '小学 / 初中 / 高中 / 成年人，或自定义。',
        ),
        const SizedBox(height: 10),
        _ChipGroup(
          presets: _stages,
          customItems: _customStages,
          selected: _stage,
          customHint: '如：专升本、研究生、自学考试...',
          customTitle: '自定义学段',
          onSelected: (s) {
            HapticFeedback.selectionClick();
            setState(() => _stage = s);
          },
          onPickCustom: (preset) => _pickCustom(
            title: '自定义学段',
            hint: '如：专升本、研究生、自学考试...',
            preset: preset,
            onConfirm: (v) {
              setState(() {
                _stage = v;
                _addCustomItem(_customStages, v);
              });
              _saveLastSelection();
            },
          ),
          onRemoveCustom: (v) => _confirmRemoveCustom(
            title: '删除自定义学段',
            value: v,
            list: _customStages,
          ),
        ),
        const SizedBox(height: 18),
        const _FlowStepHeader(
          step: '04',
          title: '选择考试类型',
          subtitle: '期末 / 期中 / 中高考模拟 / 周测 / 小测，或自定义。',
        ),
        const SizedBox(height: 10),
        _ChipGroup(
          presets: _examTypes,
          customItems: _customExamTypes,
          selected: _examType,
          customHint: '如：单元测、模拟考、真题演练...',
          customTitle: '自定义类型',
          onSelected: (s) {
            HapticFeedback.selectionClick();
            setState(() => _examType = s);
          },
          onPickCustom: (preset) => _pickCustom(
            title: '自定义类型',
            hint: '如：单元测、模拟考、真题演练...',
            preset: preset,
            onConfirm: (v) {
              setState(() {
                _examType = v;
                _addCustomItem(_customExamTypes, v);
              });
              _saveLastSelection();
            },
          ),
          onRemoveCustom: (v) => _confirmRemoveCustom(
            title: '删除自定义类型',
            value: v,
            list: _customExamTypes,
          ),
        ),
        const SizedBox(height: 18),
        const _FlowStepHeader(
          step: '05',
          title: '选择试卷页数',
          subtitle: '2 / 4 / 6 / 8 面或自定义，最多 12 面。',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kLine),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._pageOptions.map((p) {
                final selected = _pageCount == p;
                return _PresetChip(
                  label: '$p 面',
                  selected: selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _pageCount = p);
                  },
                );
              }),
              _PresetChip(
                label: _pageOptions.contains(_pageCount)
                    ? '自定义'
                    : '$_pageCount 面',
                selected: !_pageOptions.contains(_pageCount),
                onTap: _pickCustomPage,
                isCustom: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _NoteCard(
          title: '关于 token 消耗',
          body: '整套试卷题量大，token 消耗高于普通出题。建议优先使用上下文长、价格低的模型（如 DeepSeek）。',
        ),
        const SizedBox(height: 12),
        // 「更多选项」折叠区：总分 + 各题型小题分值
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kLine),
          ),
          child: ExpansionTile(
            initiallyExpanded: _moreExpanded,
            onExpansionChanged: (v) =>
                setState(() => _moreExpanded = v),
            tilePadding: const EdgeInsets.symmetric(horizontal: 18),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Row(
              children: [
                const Icon(Icons.tune, size: 18, color: kMuted),
                const SizedBox(width: 8),
                const Text(
                  '更多选项',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                const SizedBox(width: 8),
                if (_totalScoreMode > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: kBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '满分 ${_buildScoreConfig().effectiveTotal} 分',
                      style: const TextStyle(
                        fontSize: 11,
                        color: kBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 题量模板
                    const Text(
                      '题量模板',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '默认按学段+学科+考试类型自动套用真实考试结构',
                      style: TextStyle(fontSize: 11, color: kMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ScoreOptionChip(
                          label: '默认模板',
                          selected: _templateMode == 0,
                          onTap: () => setState(() => _templateMode = 0),
                        ),
                        _ScoreOptionChip(
                          label: '自定义题量',
                          selected: _templateMode == 1,
                          onTap: () => setState(() => _templateMode = 1),
                        ),
                      ],
                    ),
                    if (_templateMode == 1) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '各大题题量',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ScoreNumberField(
                        label: '选择题数',
                        value: _customChoiceCount,
                        onChanged: (v) =>
                            setState(() => _customChoiceCount = v),
                      ),
                      _ScoreNumberField(
                        label: '填空题数',
                        value: _customFillCount,
                        onChanged: (v) =>
                            setState(() => _customFillCount = v),
                      ),
                      _ScoreNumberField(
                        label: '判断题数',
                        value: _customJudgeCount,
                        onChanged: (v) =>
                            setState(() => _customJudgeCount = v),
                      ),
                      _ScoreNumberField(
                        label: '解答题数',
                        value: _customSubjectiveCount,
                        onChanged: (v) =>
                            setState(() => _customSubjectiveCount = v),
                      ),
                    ],
                    const Divider(height: 32),
                    const Text(
                      '总分设置',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ScoreOptionChip(
                          label: '自动',
                          selected: _totalScoreMode == 0,
                          onTap: () => setState(() => _totalScoreMode = 0),
                        ),
                        _ScoreOptionChip(
                          label: '100 分',
                          selected: _totalScoreMode == 1,
                          onTap: () => setState(() => _totalScoreMode = 1),
                        ),
                        _ScoreOptionChip(
                          label: '120 分',
                          selected: _totalScoreMode == 2,
                          onTap: () => setState(() => _totalScoreMode = 2),
                        ),
                        _ScoreOptionChip(
                          label: '150 分',
                          selected: _totalScoreMode == 3,
                          onTap: () => setState(() => _totalScoreMode = 3),
                        ),
                        _ScoreOptionChip(
                          label: _totalScoreMode == 4
                              ? '$_customTotal 分'
                              : '自定义',
                          selected: _totalScoreMode == 4,
                          onTap: () => _pickCustomScore(
                            title: '自定义总分',
                            hint: '请输入整数（如 80）',
                            initial: _customTotal,
                            onConfirm: (v) => setState(() {
                              _customTotal = v;
                              _totalScoreMode = 4;
                            }),
                          ),
                          isCustom: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '小题分值',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '设定每种题型的单题分值，仅影响卷面分值标注',
                      style: TextStyle(fontSize: 11, color: kMuted),
                    ),
                    const SizedBox(height: 8),
                    _ScoreNumberField(
                      label: '选择题 / 题',
                      value: _choiceScore,
                      onChanged: (v) =>
                          setState(() => _choiceScore = v),
                    ),
                    _ScoreNumberField(
                      label: '填空题 / 空',
                      value: _fillScore,
                      onChanged: (v) => setState(() => _fillScore = v),
                    ),
                    _ScoreNumberField(
                      label: '判断题 / 题',
                      value: _judgeScore,
                      onChanged: (v) =>
                          setState(() => _judgeScore = v),
                    ),
                    _ScoreNumberField(
                      label: '解答题 / 题',
                      value: _subjectiveScore,
                      onChanged: (v) =>
                          setState(() => _subjectiveScore = v),
                    ),
                    const Divider(height: 32),
                    // v2.7.1 按章节/知识点出题
                    const Text(
                      '按章节 / 知识点出题（可选）',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '留空则按资料整体出题；填写后 AI 会围绕指定章节/知识点出题',
                      style: TextStyle(fontSize: 11, color: kMuted),
                    ),
                    const SizedBox(height: 8),
                    _PaperTextField(
                      label: '出题章节范围',
                      hint: '如：第1-3章 / 第2章第3节',
                      initialValue: _chapterRange,
                      onChanged: (v) =>
                          setState(() => _chapterRange = v),
                    ),
                    _PaperTextField(
                      label: '选择题 知识点',
                      hint: '如：二次函数、概率（逗号分隔）',
                      initialValue: _choiceKp,
                      onChanged: (v) => setState(() => _choiceKp = v),
                    ),
                    _PaperTextField(
                      label: '填空题 知识点',
                      hint: '如：立体几何、三角函数',
                      initialValue: _fillKp,
                      onChanged: (v) => setState(() => _fillKp = v),
                    ),
                    _PaperTextField(
                      label: '判断题 知识点',
                      hint: '如：物理概念、单位换算',
                      initialValue: _judgeKp,
                      onChanged: (v) => setState(() => _judgeKp = v),
                    ),
                    _PaperTextField(
                      label: '解答题 知识点',
                      hint: '如：综合应用、证明题',
                      initialValue: _subjectiveKp,
                      onChanged: (v) => setState(() => _subjectiveKp = v),
                    ),
                    const SizedBox(height: 14),
                    // v2.7.2 细化：每题指定知识点（多行输入）
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune, size: 16, color: Color(0xFFD97706)),
                              SizedBox(width: 6),
                              Text(
                                '每题知识点细化（可选）',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '每行一题，格式：第N题: 知识点1、知识点2\n如：第1题: 二次函数图像；第2题: 概率计算',
                            style: TextStyle(fontSize: 11, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PaperTextField(
                      label: '每题知识点',
                      hint: '第1题: 二次函数\n第2题: 概率\n第3题: 立体几何',
                      initialValue: _perQuestionKp,
                      maxLines: 4,
                      onChanged: (v) => setState(() => _perQuestionKp = v),
                    ),
                    const SizedBox(height: 12),
                    // v2.7.2 细化：主观题小问数与难度
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.format_list_numbered, size: 16, color: kBlue),
                              SizedBox(width: 6),
                              Text(
                                '解答题小问与难度（可选）',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: kBlue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '每行一题，格式：第N题: X问(难度)\n难度选项：简单/中/难\n如：第1题: 3问(简单-中-难)；第2题: 2问(中-难)',
                            style: TextStyle(fontSize: 11, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PaperTextField(
                      label: '解答题小问与难度',
                      hint: '第1题: 3问(简单-中-难)\n第2题: 2问(中-难)\n第3题: 2问(难-难)',
                      initialValue: _subjectiveSubQuestions,
                      maxLines: 4,
                      onChanged: (v) => setState(() => _subjectiveSubQuestions = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // 启用图表渲染开关
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.enableRichContent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.enableRichContent ? const Color(0xFF93C5FD) : kLine,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.enableRichContent
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: widget.enableRichContent ? Colors.white : kMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '启用图表/公式渲染',
                      style: TextStyle(fontWeight: FontWeight.w900, color: kInk),
                    ),
                    Text(
                      widget.enableRichContent ? '已开启：图表题约占全卷 25%（保持在 20%-30%）' : '关闭：纯文字试卷，生成更快',
                      style: const TextStyle(color: kMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.enableRichContent,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  widget.onToggleRichContent(v);
                },
                activeThumbColor: kBlue,
              ),
            ],
          ),
        ),
        // 启用音频题开关
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.enableListening ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.enableListening ? const Color(0xFF86EFAC) : kLine,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.enableListening
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  color: widget.enableListening ? Colors.white : kMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '启用音频题（英语听力）',
                      style: TextStyle(fontWeight: FontWeight.w900, color: kInk),
                    ),
                    Text(
                      widget.enableListening ? '已开启：听力题约占全卷 25%（保持在 20%-30%）' : '关闭：纯文字题，无听力音频',
                      style: const TextStyle(color: kMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.enableListening,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  widget.onToggleListening(v);
                },
                activeThumbColor: const Color(0xFF10B981),
              ),
            ],
          ),
        ),
        // v2.7.4: 听力题数量设定（仅在启用听力时显示）
        if (widget.enableListening)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF5EEAD4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered_rounded,
                    color: Color(0xFF0D9488), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '听力题数量',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: kInk,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _listeningCount == 0
                            ? '0 = 自动（按总题数约 25% 占比）'
                            : '$_listeningCount 道听力题',
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _listeningCount <= 0
                          ? null
                          : () {
                          HapticFeedback.selectionClick();
                          setState(() => _listeningCount = (_listeningCount - 1).clamp(0, 30));
                          _saveLastSelection();
                        },
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: const Color(0xFF0D9488),
                      iconSize: 26,
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$_listeningCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _listeningCount >= 30
                          ? null
                          : () {
                          HapticFeedback.selectionClick();
                          setState(() => _listeningCount = (_listeningCount + 1).clamp(0, 30));
                          _saveLastSelection();
                        },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: const Color(0xFF0D9488),
                      iconSize: 26,
                    ),
                  ],
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.generating || activeMaterial == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    final gradeLevel = '$_stage·$_examType';
                    _saveLastSelection();
                    widget.onGenerate(
                      subject: _subject,
                      gradeLevel: gradeLevel,
                      pageCount: _pageCount,
                      material: activeMaterial,
                      scoreConfig: _buildScoreConfig(),
                      template: _buildTemplate(),
                      chapterRange: _chapterRange,
                      knowledgePointSpec: _buildKnowledgePointSpec(),
                      listeningCount: _listeningCount,
                    );
                  },
            icon: widget.generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(widget.generating ? '生成中...' : '生成试卷'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ),
        if (!widget.configReady) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: widget.onOpenConfig,
            icon: const Icon(Icons.key_rounded, size: 18),
            label: const Text('请先配置 API'),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '历史试卷',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kInk,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.papers.length} 份 · ${grouped.length} 个资料',
                  style: const TextStyle(
                    color: kMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.papers.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: '清理',
                    icon: const Icon(Icons.cleaning_services_outlined, color: kInk, size: 22),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'batch_papers',
                        child: ListTile(
                          leading: Icon(Icons.checklist_rounded, color: kBlue),
                          title: Text('批量删除试卷'),
                          subtitle: Text('勾选要删除的试卷（可全选）'),
                          dense: true,
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'batch_papers') {
                        await _showBatchDeletePapersSheet();
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.papers.isEmpty)
          const _EmptyCard(
            icon: Icons.description_outlined,
            title: '还没有生成过试卷',
            subtitle: '选好资料、学科、学段、类型和页数后，点击“生成试卷”。',
          )
        else
          _CollapsibleSection(
            itemCount: grouped.length,
            visibleCount: 5,
            label: '份资料',
            itemBuilder: (i) {
              final entry = grouped.entries.elementAt(i);
              final papers = entry.value;
              return _PaperGroupCard(
                materialName: entry.key,
                papers: papers,
                cnIndex: (idx) => cn(idx),
                onView: widget.onView,
                onDelete: widget.onDelete,
                onDownload: widget.onDownload,
                onDownloadAnswer: widget.onDownloadAnswer,
                onDownloadAudio: widget.onDownloadAudio,
              );
            },
          ),
      ],
    );
  }
}

/// 通用 chip 选择组：预设 + 已添加的自定义项 + 末尾一个"自定义" chip
/// 用户每添加一个自定义项，它会作为新的预设项保留下来，"自定义" chip 始终在末尾
class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.presets,
    required this.selected,
    required this.customTitle,
    required this.customHint,
    required this.onSelected,
    required this.onPickCustom,
    this.customItems = const [],
    this.onRemoveCustom,
  });
  final List<String> presets;
  final List<String> customItems;
  final String selected;
  final String customTitle;
  final String customHint;
  final ValueChanged<String> onSelected;
  final void Function(String preset) onPickCustom;
  /// 长按自定义项删除回调（仅自定义项触发）
  final void Function(String customItem)? onRemoveCustom;

  @override
  Widget build(BuildContext context) {
    final allPresets = <String>[...presets, ...customItems];
    final isCustomSelected = !allPresets.contains(selected);
    final customSet = customItems.toSet();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ...allPresets.map((s) => _PresetChip(
                label: s,
                selected: selected == s,
                onTap: () => onSelected(s),
                onLongPress: customSet.contains(s) && onRemoveCustom != null
                    ? () => onRemoveCustom!(s)
                    : null,
                isCustomAdded: customSet.contains(s),
              )),
          _PresetChip(
            label: isCustomSelected ? selected : '自定义',
            selected: isCustomSelected,
            onTap: () => onPickCustom(isCustomSelected ? selected : ''),
            isCustom: true,
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isCustom = false,
    this.isCustomAdded = false,
    this.onLongPress,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isCustom;
  /// 是否为用户已添加的自定义项（用于显示删除提示小圆点）
  final bool isCustomAdded;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom) ...[
              Icon(
                Icons.tune,
                size: 14,
                color: selected ? Colors.white : kMuted,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : kInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isCustomAdded) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.close,
                size: 12,
                color: selected ? Colors.white.withValues(alpha: 0.7) : kMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 分值选项 chip（用于"总分设置"）
class _ScoreOptionChip extends StatelessWidget {
  const _ScoreOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isCustom = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom) ...[
              Icon(
                Icons.tune,
                size: 13,
                color: selected ? Colors.white : kMuted,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : kInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 数字输入行（用于"小题分值"）
class _ScoreNumberField extends StatelessWidget {
  const _ScoreNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: kInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: value > 1
                    ? () {
                        HapticFeedback.selectionClick();
                        onChanged(value - 1);
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
              ),
              IconButton(
                onPressed: value < 100
                    ? () {
                        HapticFeedback.selectionClick();
                        onChanged(value + 1);
                      }
                    : null,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// v2.7.1 试卷出题"按章节/知识点"文字输入框
class _PaperTextField extends StatefulWidget {
  const _PaperTextField({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
  });
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<_PaperTextField> createState() => _PaperTextFieldState();
}

class _PaperTextFieldState extends State<_PaperTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              color: kInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            maxLines: widget.maxLines,
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kLine),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBlue, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 13, color: kInk),
          ),
        ],
      ),
    );
  }
}

/// 按资料分组展示试卷
class _PaperGroupCard extends StatelessWidget {
  const _PaperGroupCard({
    required this.materialName,
    required this.papers,
    required this.cnIndex,
    required this.onView,
    required this.onDelete,
    required this.onDownload,
    required this.onDownloadAnswer,
    required this.onDownloadAudio,
  });
  final String materialName;
  final List<Paper> papers;
  final String Function(int i) cnIndex;
  final ValueChanged<Paper> onView;
  final void Function(String id, String name) onDelete;
  final ValueChanged<Paper> onDownload;
  final ValueChanged<Paper> onDownloadAnswer;
  final ValueChanged<Paper> onDownloadAudio;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, color: kBlue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    materialName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: kInk,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${papers.length} 份',
                    style: const TextStyle(
                      color: kBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kLine),
          // 试卷列表
          ...papers.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final title = '试卷${cnIndex(i)}';
            return _PaperListTile(
              title: title,
              paper: p,
              onView: () => onView(p),
              onDelete: () => onDelete(p.id, '$title · ${p.subject}'),
              onDownload: () => onDownload(p),
              onDownloadAnswer: () => onDownloadAnswer(p),
              onDownloadAudio: () => onDownloadAudio(p),
            );
          }),
        ],
      ),
    );
  }
}

class _PaperListTile extends StatelessWidget {
  const _PaperListTile({
    required this.title,
    required this.paper,
    required this.onView,
    required this.onDelete,
    required this.onDownload,
    required this.onDownloadAnswer,
    required this.onDownloadAudio,
  });
  final String title;
  final Paper paper;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onDownload;
  final VoidCallback onDownloadAnswer;
  final VoidCallback onDownloadAudio;

  /// 是否含听力题
  bool get _hasListening => paper.questions.any((q) =>
      q.question.richContent.any((rc) => (rc['type'] ?? '') == 'listening'));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description_outlined,
                color: kBlue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onView,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: kInk,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          paper.subject,
                          style: const TextStyle(
                            fontSize: 10,
                            color: kMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${paper.gradeLevel} · ${paper.pageCount}面 · ${paper.questions.length}题 · ${_dateText(paper.createdAt)}',
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '预览',
            icon: const Icon(Icons.visibility_outlined,
                color: kBlue, size: 20),
            onPressed: onView,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '下载试卷',
            icon: const Icon(Icons.download_outlined,
                color: kMuted, size: 20),
            onPressed: onDownload,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '下载答案',
            icon: const Icon(Icons.task_alt, color: kMuted, size: 20),
            onPressed: onDownloadAnswer,
            visualDensity: VisualDensity.compact,
          ),
          if (_hasListening)
            IconButton(
              tooltip: '下载听力音频（mp3）',
              icon: const Icon(Icons.headphones,
                  color: Color(0xFF7C3AED), size: 20),
              onPressed: onDownloadAudio,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline,
                color: kRed, size: 20),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ============ 试卷预览页 ============

class PaperViewer extends StatefulWidget {
  const PaperViewer({super.key, required this.paper, this.onDownload, this.onDownloadAnswer, this.onDownloadAudio});
  final Paper paper;
  final VoidCallback? onDownload;
  final VoidCallback? onDownloadAnswer;
  final VoidCallback? onDownloadAudio;

  @override
  State<PaperViewer> createState() => _PaperViewerState();
}

class _PaperViewerState extends State<PaperViewer> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    final sections = <String, List<PaperQuestion>>{};
    for (final q in paper.questions) {
      sections.putIfAbsent(q.section.isEmpty ? '题目' : q.section, () => []).add(q);
    }
    final sectionKeys = sections.keys.toList();
    final hasListening = paper.questions.any((q) =>
        q.question.richContent.any((rc) => (rc['type'] ?? '') == 'listening'));

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text('${paper.subject} 试卷'),
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_showAnswer ? Icons.visibility_off : Icons.visibility),
            tooltip: _showAnswer ? '隐藏答案' : '查看答案',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _showAnswer = !_showAnswer);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_outlined),
            tooltip: '下载',
            onSelected: (v) {
              if (v == 'paper') {
                widget.onDownload?.call();
              } else if (v == 'answer') {
                widget.onDownloadAnswer?.call();
              } else if (v == 'audio') {
                widget.onDownloadAudio?.call();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'paper',
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('下载试卷'),
                  subtitle: Text(
                    '导出为 PDF 文件',
                    style: TextStyle(fontSize: 11),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'answer',
                child: ListTile(
                  leading: Icon(Icons.task_alt),
                  title: Text('下载答案'),
                  subtitle: Text(
                    '导出含答案与解析的 PDF',
                    style: TextStyle(fontSize: 11),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (hasListening && widget.onDownloadAudio != null)
                const PopupMenuItem(
                  value: 'audio',
                  child: ListTile(
                    leading: Icon(Icons.headphones, color: Color(0xFF7C3AED)),
                    title: Text('下载听力音频'),
                    subtitle: Text(
                      '导出为 mp3 格式',
                      style: TextStyle(fontSize: 11),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // 试卷头部
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kLine),
              ),
              child: Column(
                children: [
                  Text(
                    paper.gradeLevel,
                    style: const TextStyle(
                      color: kMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${paper.subject}试卷',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PaperMeta(label: '页数', value: '${paper.pageCount}'),
                      _PaperMeta(
                          label: '题数', value: '${paper.questions.length}'),
                      _PaperMeta(
                          label: '生成', value: _dateText(paper.createdAt)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '资料：${paper.materialName}',
                    style: const TextStyle(color: kMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _showAnswer
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _showAnswer ? Icons.check_circle : Icons.info_outline,
                    size: 18,
                    color: _showAnswer
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _showAnswer ? '当前显示答案与解析' : '当前为试题预览（不含答案），点右上角切换',
                      style: TextStyle(
                        color: _showAnswer
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...sectionKeys.expand((section) {
              final list = sections[section]!;
              return [
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    section,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: kBlue,
                    ),
                  ),
                ),
                ...list.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final q = entry.value.question;
                  return _PaperQuestionTile(
                    index: idx,
                    question: q,
                    showAnswer: _showAnswer,
                  );
                }),
                const SizedBox(height: 16),
              ];
            }),
          ],
        ),
      ),
    );
  }
}

class _PaperMeta extends StatelessWidget {
  const _PaperMeta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, color: kInk),
        ),
      ],
    );
  }
}

class _PaperQuestionTile extends StatelessWidget {
  const _PaperQuestionTile({
    required this.index,
    required this.question,
    required this.showAnswer,
  });
  final int index;
  final AiQuestion question;
  final bool showAnswer;

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index. ',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: kInk,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        q.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: kMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 图表状态指示器（debug）
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: q.richContent.isNotEmpty
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: q.richContent.isNotEmpty
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFFED7AA),
              ),
            ),
            child: Text(
              q.richContent.isNotEmpty
                  ? '📊 图表已启用 (${q.richContent.length}个：${q.richContent.map((r) => r['type']).join(',')})'
                  : '⚠️ 纯文字题（无图表）',
              style: TextStyle(
                fontSize: 10,
                color: q.richContent.isNotEmpty
                    ? const Color(0xFF166534)
                    : const Color(0xFF9A3412),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (q.options.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...q.options.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    o,
                    style: const TextStyle(color: kInk, height: 1.5),
                  ),
                )),
          ],
          // v2.7.3: 富内容（听力音频/图表/公式）始终随题目显示，不只在答案模式下显示
          // v2.7.4: 试卷预览中听力原文隐藏，只显示播放按钮
          if (q.richContent.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...q.richContent.map((rc) => RichContentBlock(
                  type: rc['type'] as String? ?? '',
                  data: (rc['data'] as Map?)?.cast<String, dynamic>() ?? const {},
                  hideListeningText: true,
                )),
          ],
          if (showAnswer) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '答案：',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                  ),
                ),
                Expanded(
                  child: Text(
                    q.answer.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '解析：',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: kMuted,
                  ),
                ),
                Expanded(
                  child: Text(
                    q.explanation,
                    style: const TextStyle(color: kMuted, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class MePage extends StatefulWidget {
  const MePage({
    super.key,
    required this.records,
    required this.wrongs,
    required this.xpProfile,
    required this.configReady,
    required this.onCheckIn,
    required this.onOpenConfig,
    required this.onOpenFeedback,
    required this.onClearRecords,
    required this.onClearWrongs,
    required this.onDeleteRecord,
    required this.onDeleteWrong,
    required this.onDeleteRecords,
    required this.onDeleteWrongs,
    required this.practiceLog,
  });

  final List<PracticeRecord> records;
  final List<WrongItem> wrongs;
  final XpProfile xpProfile;
  final bool configReady;
  final VoidCallback onCheckIn;
  final VoidCallback onOpenConfig;
  final VoidCallback onOpenFeedback;
  /// 一键清空全部历史记录
  final VoidCallback onClearRecords;
  /// 一键清空全部错题
  final VoidCallback onClearWrongs;
  /// 删除单条历史记录
  final void Function(PracticeRecord record) onDeleteRecord;
  /// 删除单条错题
  final void Function(WrongItem item) onDeleteWrong;
  /// 批量删除历史记录
  final void Function(List<PracticeRecord> records) onDeleteRecords;
  /// 批量删除错题
  final void Function(List<WrongItem> wrongs) onDeleteWrongs;
  /// v2.7.3: 每日练习趋势日志（date_key -> 当日做题数），独立于 records
  final Map<String, int> practiceLog;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  String _query = '';
  bool _searchMode = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 在历史记录中检索：匹配资料名、知识点
  bool _matchRecord(PracticeRecord r) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    if (r.materialName.toLowerCase().contains(q)) return true;
    for (final item in r.questionStats) {
      if (item.knowledgePoint.toLowerCase().contains(q)) return true;
      if (item.type.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmText = '确认',
  }) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// 批量删除历史记录：弹窗列出全部记录，多选后回调
  Future<void> _showBatchDeleteRecordsSheet() async {
    final records = widget.records;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('历史记录已经是空的'), duration: Duration(seconds: 1)),
      );
      return;
    }
    final selected = <int>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18, 14, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '批量删除历史记录',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kInk),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              if (selected.length == records.length) {
                                selected.clear();
                              } else {
                                selected.addAll(List.generate(records.length, (i) => i));
                              }
                            });
                          },
                          child: Text(
                            selected.length == records.length ? '取消全选' : '全选',
                            style: const TextStyle(color: kBlue, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '已选 ${selected.length} / ${records.length} 条；勾选后点击底部按钮删除。',
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = records[i];
                          final checked = selected.contains(i);
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheet(() {
                                if (checked) {
                                  selected.remove(i);
                                } else {
                                  selected.add(i);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: checked ? kBlue : kMuted,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.materialName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: kInk),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_dateText(r.createdAt)} · 正确 ${r.correct}/${r.total}',
                                          style: const TextStyle(color: kMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(ctx, true),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(selected.isEmpty ? '未选择' : '删除选中 (${selected.length})'),
                            style: FilledButton.styleFrom(backgroundColor: kRed),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed == true && selected.isNotEmpty) {
      final toDelete = selected.map((i) => records[i]).toList();
      final ok = await _confirm(
        title: '确认删除选中的历史记录？',
        message: '将删除 ${toDelete.length} 条记录，删除后无法恢复。',
        confirmText: '删除',
      );
      if (ok) widget.onDeleteRecords(toDelete);
    }
  }

  /// 批量删除错题：弹窗列出全部错题，多选后回调
  Future<void> _showBatchDeleteWrongsSheet() async {
    final wrongs = widget.wrongs;
    if (wrongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('错题本已经是空的'), duration: Duration(seconds: 1)),
      );
      return;
    }
    final selected = <int>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18, 14, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '批量删除错题',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kInk),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              if (selected.length == wrongs.length) {
                                selected.clear();
                              } else {
                                selected.addAll(List.generate(wrongs.length, (i) => i));
                              }
                            });
                          },
                          child: Text(
                            selected.length == wrongs.length ? '取消全选' : '全选',
                            style: const TextStyle(color: kBlue, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '已选 ${selected.length} / ${wrongs.length} 道；勾选后点击底部按钮删除。',
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: wrongs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final w = wrongs[i];
                          final checked = selected.contains(i);
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheet(() {
                                if (checked) {
                                  selected.remove(i);
                                } else {
                                  selected.add(i);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: checked ? kBlue : kMuted,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          w.materialName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: kInk),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          w.question.question,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: kInk, fontSize: 12, height: 1.4),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_dateText(w.createdAt)} · 你的答案：${w.userAnswer.isEmpty ? "（空）" : w.userAnswer}',
                                          style: const TextStyle(color: kMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(ctx, true),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(selected.isEmpty ? '未选择' : '删除选中 (${selected.length})'),
                            style: FilledButton.styleFrom(backgroundColor: kRed),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed == true && selected.isNotEmpty) {
      final toDelete = selected.map((i) => wrongs[i]).toList();
      final ok = await _confirm(
        title: '确认删除选中的错题？',
        message: '将删除 ${toDelete.length} 道错题，删除后无法恢复。',
        confirmText: '删除',
      );
      if (ok) widget.onDeleteWrongs(toDelete);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    final wrongs = widget.wrongs;
    final xpProfile = widget.xpProfile;
    final total = records.fold<int>(0, (sum, item) => sum + item.total);
    final correct = records.fold<int>(0, (sum, item) => sum + item.correct);
    final accuracy = total == 0 ? 0 : (correct / total * 100).round();
    final now = DateTime.now();
    // v2.7.3: 本周练习趋势从独立持久化的 practiceLog 读取，删除历史记录不影响趋势
    final practiceLog = widget.practiceLog;
    final weeklyValues = List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      final key = _dateKey(day);
      return practiceLog[key] ?? 0;
    });
    final weeklyTotal = weeklyValues.fold<int>(0, (sum, value) => sum + value);

    // 检索结果
    final filteredRecords = records.where(_matchRecord).toList();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(
              child: _PageTitle(title: '我的', subtitle: '学习数据、API 配置和项目信息都在这里。'),
            ),
            IconButton(
              tooltip: _searchMode ? '关闭检索' : '检索历史/错题',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _searchMode = !_searchMode;
                  if (!_searchMode) {
                    _controller.clear();
                    _query = '';
                  }
                });
              },
              icon: Icon(
                _searchMode ? Icons.search_off_rounded : Icons.search_rounded,
                color: kInk,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '清理',
              icon: const Icon(Icons.cleaning_services_outlined, color: kInk),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'batch_records',
                  child: ListTile(
                    leading: Icon(Icons.checklist_rounded, color: kBlue),
                    title: Text('批量删除历史记录'),
                    subtitle: Text('勾选要删除的记录（可全选）'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'batch_wrongs',
                  child: ListTile(
                    leading: Icon(Icons.checklist_rounded, color: kRed),
                    title: Text('批量删除错题'),
                    subtitle: Text('勾选要删除的错题（可全选）'),
                    dense: true,
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'batch_records') {
                  await _showBatchDeleteRecordsSheet();
                } else if (value == 'batch_wrongs') {
                  await _showBatchDeleteWrongsSheet();
                }
              },
            ),
          ],
        ),
        if (_searchMode) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kLine),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: '搜索资料名 / 题干 / 知识点',
                border: InputBorder.none,
                icon: Icon(Icons.search, size: 20, color: kMuted),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '命中 ${filteredRecords.length} 条历史记录',
                style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 16),
        ],
        _XpPanel(profile: xpProfile, onCheckIn: widget.onCheckIn),
        const SizedBox(height: 16),
        _WeeklyTrendCard(values: weeklyValues, total: weeklyTotal),
        const SizedBox(height: 16),
        _ConfigEntryCard(configReady: widget.configReady, onTap: widget.onOpenConfig),
        const SizedBox(height: 16),
        _FeedbackEntryCard(onTap: widget.onOpenFeedback),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.18,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              icon: Icons.task_alt_rounded,
              label: '累计做题',
              value: '$total',
            ),
            _StatCard(
              icon: Icons.verified_rounded,
              label: '正确题数',
              value: '$correct',
              color: kGreen,
            ),
            _StatCard(
              icon: Icons.speed_rounded,
              label: '正确率',
              value: '$accuracy%',
            ),
            _StatCard(
              icon: Icons.bookmark_remove_outlined,
              label: '错题数',
              value: '${wrongs.length}',
              color: kRed,
            ),
          ],
        ),
        const SizedBox(height: 18),
        // 历史记录（带检索）
        Row(
          children: [
            Expanded(
              child: _SectionHeader(
                title: '练习历史',
                subtitle: _query.isEmpty
                    ? '${records.length} 次记录'
                    : '${filteredRecords.length}/${records.length} 条命中',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const _EmptyCard(
            icon: Icons.history,
            title: '还没有练习历史',
            subtitle: '完成一组题目后会显示在这里。',
          )
        else if (_searchMode && filteredRecords.isEmpty)
          const _EmptyCard(
            icon: Icons.search_off,
            title: '没有匹配的历史记录',
            subtitle: '换个关键词试试。',
          )
        else
          _CollapsibleSection(
            itemCount: filteredRecords.length,
            // 检索模式下不折叠（用户主动在找），普通模式下只显示最近 5 条
            visibleCount: _searchMode ? filteredRecords.length : 5,
            label: '次记录',
            itemBuilder: (i) => _PracticeRecordTile(
              record: filteredRecords[i],
              onDelete: () async {
                final record = filteredRecords[i];
                final ok = await _confirm(
                  title: '删除该历史记录？',
                  message: '将删除「${record.materialName}」的练习记录，删除后无法恢复。',
                  confirmText: '删除',
                );
                if (ok) widget.onDeleteRecord(record);
              },
            ),
          ),
        const SizedBox(height: 18),
        const _AboutAppCard(),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color = kBlue,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: kMuted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _WeeklyTrendCard extends StatelessWidget {
  const _WeeklyTrendCard({required this.values, required this.total});

  final List<int> values;
  final int total;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 1 : max(1, values.reduce(max));
    final now = DateTime.now();
    const weekNames = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.show_chart_rounded, color: kBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '本周练习趋势',
                      style: TextStyle(
                        color: kInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '近 7 天共完成 $total 道题',
                      style: const TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _TinyBadge(label: total >= 30 ? '节奏不错' : '继续加油'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 102,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (index) {
                final value = values[index];
                final height = 20 + (value / maxValue) * 62;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$value',
                          style: const TextStyle(
                            color: kMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          height: height,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF93C5FD), kBlue],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(values.length, (index) {
              final day = now.subtract(
                Duration(days: values.length - 1 - index),
              );
              final label = weekNames[day.weekday - 1];
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PracticeRecordTile extends StatelessWidget {
  const _PracticeRecordTile({required this.record, this.onDelete});

  final PracticeRecord record;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = record.isWrongCardChallenge
        ? kBlue
        : (record.accuracy >= 60 ? kGreen : kRed);
    return Dismissible(
      key: ValueKey('record_${record.createdAt.toIso8601String()}_${record.materialName}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kRed,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        if (onDelete == null) return false;
        HapticFeedback.mediumImpact();
        onDelete!();
        return false; // 由回调处理实际删除
      },
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PracticeHistoryDetailPage(record: record),
            ),
          );
        },
        onLongPress: onDelete == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onDelete!();
              },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kLine),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  record.isWrongCardChallenge
                      ? Icons.style_rounded
                      : Icons.assignment_turned_in_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.materialName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.correct}/${record.total} 正确 · +${record.xpEarned} XP · ${_dateText(record.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right,
                color: accent.withValues(alpha: 0.6),
                size: 22,
              ),
              const SizedBox(width: 4),
              Text(
                record.isWrongCardChallenge ? '抽卡' : '${record.accuracy}%',
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 练习历史详情页：直方图 + 圆饼图 + 动画
class PracticeHistoryDetailPage extends StatefulWidget {
  const PracticeHistoryDetailPage({super.key, required this.record});

  final PracticeRecord record;

  @override
  State<PracticeHistoryDetailPage> createState() =>
      _PracticeHistoryDetailPageState();
}

class _PracticeHistoryDetailPageState extends State<PracticeHistoryDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _anim.forward());
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final stats = r.questionStats;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kInk,
        elevation: 0,
        title: const Text(
          '练习详情',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _DetailHeader(record: r),
          const SizedBox(height: 16),
          // 圆饼图：正确 vs 错误
          _ChartCard(
            title: '正确率分布',
            subtitle: '正确 ${r.correct} 题 · 错误 ${r.wrong} 题',
            child: AnimatedBuilder(
              animation: _curve,
              builder: (context, _) {
                return _AccuracyPie(
                  correct: r.correct,
                  wrong: r.wrong,
                  progress: _curve.value,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // 直方图 1：题型分布
          _ChartCard(
            title: '题型分布',
            subtitle: '每种题型的对错情况',
            child: AnimatedBuilder(
              animation: _curve,
              builder: (context, _) {
                return _TypeHistogram(
                  stats: stats,
                  progress: _curve.value,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // 直方图 2：错题知识点 Top 5
          _ChartCard(
            title: '错题知识点 Top 5',
            subtitle: '错误最多的知识点',
            child: AnimatedBuilder(
              animation: _curve,
              builder: (context, _) {
                return _KnowledgeHistogram(
                  stats: stats,
                  progress: _curve.value,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.record});
  final PracticeRecord record;

  @override
  Widget build(BuildContext context) {
    final accent = record.isWrongCardChallenge
        ? kBlue
        : (record.accuracy >= 60 ? kGreen : kRed);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  record.isWrongCardChallenge
                      ? Icons.style_rounded
                      : Icons.assignment_turned_in_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.materialName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.isWrongCardChallenge ? '错题抽卡挑战' : '常规练习',
                      style: const TextStyle(
                        fontSize: 12,
                        color: kMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(label: '总题数', value: '${record.total}', color: kInk),
              _MiniStat(
                  label: '正确', value: '${record.correct}', color: kGreen),
              _MiniStat(label: '错误', value: '${record.wrong}', color: kRed),
              _MiniStat(
                  label: '正确率',
                  value: '${record.accuracy}%',
                  color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _dateText(record.createdAt),
            style: const TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '+${record.xpEarned} XP',
            style: const TextStyle(
              fontSize: 14,
              color: kBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// 圆饼图：正确 vs 错误
class _AccuracyPie extends StatelessWidget {
  const _AccuracyPie({
    required this.correct,
    required this.wrong,
    required this.progress,
  });
  final int correct;
  final int wrong;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final total = correct + wrong;
    final correctRatio = total == 0 ? 0.0 : correct / total;
    final wrongRatio = total == 0 ? 0.0 : wrong / total;
    final correctPct = (correctRatio * 100).round();
    final wrongPct = (wrongRatio * 100).round();
    return LayoutBuilder(
      builder: (context, constraints) {
        // 圆饼 + 右侧图例的横向布局；圆饼尺寸不超过 180
        final maxW = constraints.maxWidth;
        final pieSize = (maxW * 0.45).clamp(120.0, 180.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: pieSize,
                  height: pieSize,
                  child: CustomPaint(
                    painter: _PiePainter(
                      correctRatio: correctRatio * progress,
                      wrongRatio: wrongRatio * progress,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Legend(
                        color: kGreen,
                        label: '正确',
                        value: '$correctPct%',
                        count: '$correct 题',
                      ),
                      const SizedBox(height: 12),
                      _Legend(
                        color: kRed,
                        label: '错误',
                        value: '$wrongPct%',
                        count: '$wrong 题',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.correctRatio, required this.wrongRatio});
  final double correctRatio;
  final double wrongRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // 背景圆
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawCircle(center, radius, bgPaint);
    if (correctRatio + wrongRatio == 0) return;
    // 错误扇形（先画，从顶部开始）
    final wrongPaint = Paint()
      ..color = kRed
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      rect,
      -pi / 2 + correctRatio * 2 * pi,
      wrongRatio * 2 * pi,
      true,
      wrongPaint,
    );
    // 正确扇形
    final correctPaint = Paint()
      ..color = kGreen
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      rect,
      -pi / 2,
      correctRatio * 2 * pi,
      true,
      correctPaint,
    );
    // 中心白圆
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.62, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) =>
      old.correctRatio != correctRatio || old.wrongRatio != wrongRatio;
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
    required this.count,
  });
  final Color color;
  final String label;
  final String value;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: kMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            count,
            style: const TextStyle(fontSize: 12, color: kMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 直方图：题型分布（每种题型一个柱，柱内分对/错）
class _TypeHistogram extends StatelessWidget {
  const _TypeHistogram({required this.stats, required this.progress});
  final List<QuestionStat> stats;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final typeLabels = <String, String>{
      'choice': '单选',
      'multi_choice': '多选',
      'fill': '填空',
      'true_false': '判断',
      'subjective': '主观',
    };
    final order = ['choice', 'multi_choice', 'fill', 'true_false', 'subjective'];
    final present = order.where((t) => stats.any((s) => s.type == t)).toList();
    if (present.isEmpty) {
      return const _EmptyChart('暂无题型数据');
    }
    // 统计每题型的对/错
    final rows = present.map((t) {
      final list = stats.where((s) => s.type == t).toList();
      final correct = list.where((s) => s.isCorrect).length;
      final wrong = list.length - correct;
      return (label: typeLabels[t] ?? t, correct: correct, wrong: wrong);
    }).toList();
    final maxVal = rows.fold<int>(1, (a, r) => a > (r.correct + r.wrong) ? a : (r.correct + r.wrong));
    return Column(
      children: rows.map((r) {
        final total = r.correct + r.wrong;
        final correctW = (r.correct / maxVal) * progress;
        final wrongW = (r.wrong / maxVal) * progress;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BarRow(
            label: r.label,
            correctWidth: correctW,
            wrongWidth: wrongW,
            correctCount: r.correct,
            wrongCount: r.wrong,
            total: total,
          ),
        );
      }).toList(),
    );
  }
}

/// 直方图：错题知识点 Top 5（按错误次数排序，错得最多的排前面）
class _KnowledgeHistogram extends StatelessWidget {
  const _KnowledgeHistogram({required this.stats, required this.progress});
  final List<QuestionStat> stats;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // 知识点兜底：若 AI 没标注，用题型作为分组依据
    final typeLabels = <String, String>{
      'choice': '选择题综合',
      'multi_choice': '多选题综合',
      'fill': '填空题综合',
      'true_false': '判断题综合',
      'subjective': '解答题综合',
    };
    final wrongMap = <String, int>{};
    final correctMap = <String, int>{};
    for (final s in stats) {
      final kp = s.knowledgePoint.trim().isNotEmpty
          ? s.knowledgePoint.trim()
          : (typeLabels[s.type] ?? '综合');
      if (s.isCorrect) {
        correctMap[kp] = (correctMap[kp] ?? 0) + 1;
      } else {
        wrongMap[kp] = (wrongMap[kp] ?? 0) + 1;
      }
    }
    if (wrongMap.isEmpty) {
      return const _EmptyChart('本次练习没有错题，继续保持！');
    }
    // 只展示出现过错题的知识点；错误次数相同时按正确次数升序稳定排序。
    final entries = wrongMap.keys.map((kp) {
      final wrong = wrongMap[kp] ?? 0;
      final correct = correctMap[kp] ?? 0;
      return MapEntry(kp, (wrong, correct));
    }).toList()
      ..sort((a, b) {
        final wrongCompare = b.value.$1.compareTo(a.value.$1);
        return wrongCompare != 0
            ? wrongCompare
            : a.value.$2.compareTo(b.value.$2);
      });
    final top = entries.take(5).toList();
    final maxVal = top.fold<int>(1, (a, e) => a > e.value.$1 ? a : e.value.$1);
    return Column(
      children: top.map((e) {
        final wrong = e.value.$1;
        final correct = e.value.$2;
        final correctW = (correct / maxVal) * progress;
        final wrongW = (wrong / maxVal) * progress;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BarRow(
            label: e.key,
            correctWidth: correctW,
            wrongWidth: wrongW,
            correctCount: correct,
            wrongCount: wrong,
            total: correct + wrong,
          ),
        );
      }).toList(),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.correctWidth,
    required this.wrongWidth,
    required this.correctCount,
    required this.wrongCount,
    required this.total,
  });
  final String label;
  final double correctWidth;
  final double wrongWidth;
  final int correctCount;
  final int wrongCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barMaxWidth = constraints.maxWidth;
        final correctPx = (correctWidth * barMaxWidth).clamp(0.0, barMaxWidth);
        final wrongPx = (wrongWidth * barMaxWidth).clamp(0.0, barMaxWidth - correctPx);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kInk,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$total 题',
                  style: const TextStyle(fontSize: 11, color: kMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFFF1F5F9)),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: correctPx,
                      child: Container(color: kGreen),
                    ),
                    Positioned(
                      left: correctPx,
                      top: 0,
                      bottom: 0,
                      width: wrongPx,
                      child: Container(color: kRed),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: kGreen),
                const SizedBox(width: 4),
                Text(
                  '对 $correctCount',
                  style: const TextStyle(fontSize: 11, color: kGreen),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.circle, size: 8, color: kRed),
                const SizedBox(width: 4),
                Text(
                  '错 $wrongCount',
                  style: const TextStyle(fontSize: 11, color: kRed),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: kMuted),
      ),
    );
  }
}

class _ConfigEntryCard extends StatelessWidget {
  const _ConfigEntryCard({required this.configReady, required this.onTap});

  final bool configReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: configReady
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                configReady ? Icons.check_circle_rounded : Icons.key_rounded,
                color: configReady ? kGreen : const Color(0xFFF97316),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'API 配置',
                    style: TextStyle(
                      color: kInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    configReady ? '已配置模型接口，可继续生成题目。' : '首次使用前，请配置自己的 API Key。',
                    style: const TextStyle(color: kMuted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: kMuted),
          ],
        ),
      ),
    );
  }
}

class _FeedbackEntryCard extends StatelessWidget {
  const _FeedbackEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.feedback_outlined,
                color: Color(0xFFF97316),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '问题反馈',
                    style: TextStyle(
                      color: kInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '遇到 bug 或有想法？写下来直接发邮件给我们。',
                    style: TextStyle(color: kMuted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: kMuted),
          ],
        ),
      ),
    );
  }
}

/// 通用折叠列表：默认只显示前 [visibleCount] 项，剩余折叠；点击按钮可展开/收起
/// 用于：我的-历史记录（5）、试卷-历史试卷（5）、错题-资料分组（3）
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    super.key,
    required this.itemCount,
    required this.visibleCount,
    required this.label,
    required this.itemBuilder,
  });

  final int itemCount;
  final int visibleCount;
  final String label;
  final Widget Function(int index) itemBuilder;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.itemCount;
    final visible = widget.visibleCount;
    if (total == 0) return const SizedBox.shrink();
    final showCount = _expanded ? total : visible.clamp(0, total);
    final hiddenCount = total - showCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < showCount; i++) widget.itemBuilder(i),
        if (hiddenCount > 0)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = !_expanded);
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: kMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _expanded
                        ? '收起 ${widget.label}'
                        : '展开剩余 ${hiddenCount} ${widget.label}',
                    style: const TextStyle(
                      color: kMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AboutAppCard extends StatelessWidget {
  const _AboutAppCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kLine),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '关于 AI题库',
            style: TextStyle(
              color: kInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'v2.7.0 · 个人 AI 学习训练台，支持多学科富内容渲染（数学公式、函数图、统计图、物理示意图、化学结构、英语听力）、试卷生成、错题本与练习历史折叠收纳。官网：aichuti.ccwu.cc，开源：github.com/Garyff1/ai-question-bank。',
            style: TextStyle(color: kMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _XpPanel extends StatelessWidget {
  const _XpPanel({required this.profile, required this.onCheckIn});

  final XpProfile profile;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final boostActive = profile.isBoostActive();
    final progress = profile.levelProgress / 100;
    final title = _levelTitle(profile.level);
    final remainToNext = 100 - profile.levelProgress;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x337C3AED),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'LV',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${profile.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${profile.totalXp} XP · 连续 ${profile.checkinStreak} 天',
                      style: const TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '再获 $remainToNext XP 可升级',
                      style: const TextStyle(
                        color: kBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(onPressed: onCheckIn, child: const Text('打卡')),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFEFF6FF),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: boostActive
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: boostActive ? const Color(0xFFFDBA74) : kLine,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  boostActive
                      ? Icons.local_fire_department_rounded
                      : Icons.style_outlined,
                  color: boostActive ? const Color(0xFFF97316) : kMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    boostActive
                        ? '三倍经验剩余 ${_durationText(profile.boostRemaining())}'
                        : '完成 5 道错题抽卡并全对，可开启 10 分钟三倍经验',
                    style: TextStyle(
                      color: boostActive ? const Color(0xFF9A3412) : kMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WrongCardDrawDialog extends StatefulWidget {
  const WrongCardDrawDialog({
    super.key,
    required this.count,
    required this.canActivateBoost,
  });

  final int count;
  final bool canActivateBoost;

  @override
  State<WrongCardDrawDialog> createState() => _WrongCardDrawDialogState();
}

class _WrongCardDrawDialogState extends State<WrongCardDrawDialog>
    with TickerProviderStateMixin {
  late final AnimationController _streamController;
  late final AnimationController _revealController;
  late final List<_CardStreamItem> _cards;
  int? _selectedIndex;
  bool _revealed = false;
  Timer? _idleTimer;

  static const _idleTimeout = Duration(seconds: 30);

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (mounted && _selectedIndex == null) {
        _streamController.stop();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _streamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14500),
    )..repeat();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _cards = List.generate(11, (index) {
      final random = Random(index * 73 + 19);
      return _CardStreamItem(
        xFactor: 0.16 + random.nextDouble() * 0.68,
        seed: random.nextDouble(),
        speed: 0.72 + random.nextDouble() * 0.42,
        rotation: (random.nextDouble() - 0.5) * 0.22,
        scale: 0.86 + random.nextDouble() * 0.22,
        drift: 10 + random.nextDouble() * 28,
      );
    });
    _startIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _streamController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  double _clamp01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  Offset _positionFor(_CardStreamItem item, Size size) {
    final progress = (_streamController.value * item.speed + item.seed) % 1.0;
    final rawX =
        size.width * item.xFactor +
        sin(progress * pi * 2 + item.seed * 7) * item.drift;
    // 给卡牌半宽和发光留出安全区，窄屏手机上也不会流出左右边界。
    final x = rawX.clamp(62.0, max(62.0, size.width - 62.0)).toDouble();
    final y = size.height + 120 - progress * (size.height + 300);
    return Offset(x, y);
  }

  void _chooseCard(int index) {
    if (_selectedIndex != null) return;
    HapticFeedback.mediumImpact();
    _idleTimer?.cancel();
    setState(() {
      _selectedIndex = index;
      _revealed = false;
    });
    _streamController.stop();
    _revealController.forward(from: 0).then((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _revealed = true);
    });
  }

  void _redraw() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = null;
      _revealed = false;
    });
    _revealController.reset();
    _streamController.repeat();
    _startIdleTimer();
  }

  Widget _buildFlowCard({
    required int index,
    required Size size,
    required bool dimmed,
  }) {
    final item = _cards[index];
    final position = _positionFor(item, size);
    final bob = sin((_streamController.value + item.seed) * pi * 2) * 0.025;
    const cardWidth = 104.0;
    const cardHeight = 148.0;
    return Positioned(
      left: position.dx - cardWidth / 2,
      top: position.dy - cardHeight / 2,
      child: GestureDetector(
        onTap: () => _chooseCard(index),
        child: Transform.rotate(
          angle:
              item.rotation +
              sin((_streamController.value + item.seed) * pi * 2) * 0.04,
          child: Transform.scale(
            scale: item.scale + bob,
            child: _DrawCard(
              active: false,
              dimmed: dimmed,
              width: cardWidth,
              height: cardHeight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedCard({required int index, required Size size}) {
    final item = _cards[index];
    final raw = _revealController.value;
    final scaleAnim = Curves.easeOutCubic.transform(_clamp01(raw / 0.72));
    final reveal = Curves.easeOut.transform(_clamp01((raw - 0.42) / 0.58));
    final glow = Curves.easeOut.transform(_clamp01((raw - 0.18) / 0.72));
    final scale = item.scale + (1.34 - item.scale) * scaleAnim;
    const cardWidth = 118.0;
    const cardHeight = 170.0;
    const glowSize = 220.0;

    // 选中卡使用填充层 + Align 锁定几何中心，不再依赖父级计算出的绝对 left。
    // 放大和翻面只改变视觉尺寸，不改变中心坐标。
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.06),
          child: SizedBox(
            key: const ValueKey('wrong-card-selected-stage'),
            width: glowSize,
            height: glowSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Opacity(
                    opacity: glow,
                    child: Container(
                      width: glowSize,
                      height: glowSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kBlue.withValues(alpha: 0.55),
                            blurRadius: 48,
                            spreadRadius: 12,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: item.rotation * (1 - scaleAnim),
                  child: Transform.scale(
                    scale: scale,
                    child: _DrawCard(
                      active: reveal > 0.5 || _revealed,
                      dimmed: false,
                      width: cardWidth,
                      height: cardHeight,
                      badgeText: '已抽 ${widget.count} 题',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCards(Size size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_streamController, _revealController]),
      builder: (context, child) {
        final selected = _selectedIndex;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (selected != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(color: Colors.black.withValues(alpha: 0.22)),
                ),
              ),
            ...List.generate(_cards.length, (index) {
              if (selected == index) return const SizedBox.shrink();
              return _buildFlowCard(
                index: index,
                size: size,
                dimmed: selected != null,
              );
            }),
            if (selected != null)
              _buildSelectedCard(index: selected, size: size),
          ],
        );
      },
    );
  }

  Widget _buildBottomPanel() {
    final selected = _selectedIndex != null;
    if (_revealed) {
      return Column(
        key: const ValueKey('revealed'),
        children: [
          const Text(
            '错题挑战已开启',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.canActivateBoost
                ? '已抽取 ${widget.count} 道历史错题，全对可开启 10 分钟三倍经验。'
                : '已抽取 ${widget.count} 道历史错题，准备开始挑战。',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _redraw,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('再抽一次'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('开始挑战'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      key: ValueKey(selected ? 'revealing' : 'ready'),
      children: [
        Text(
          selected ? '正在揭示错题卡...' : '轻点任意卡片，抽取本轮错题。',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!selected) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _chooseCard(_cards.length ~/ 2),
            icon: const Icon(Icons.style_rounded),
            label: const Text('帮我抽一张'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF020617),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _MistBackground()),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          '错题抽卡挑战',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          '跳过动画',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    widget.canActivateBoost
                        ? '本轮抽取 ${widget.count} 道错题，全对即可开启三倍经验'
                        : '当前错题不足 5 道，先完成已有错题挑战',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildCards(
                          Size(constraints.maxWidth, constraints.maxHeight),
                        );
                      },
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _buildBottomPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStreamItem {
  const _CardStreamItem({
    required this.xFactor,
    required this.seed,
    required this.speed,
    required this.rotation,
    required this.scale,
    required this.drift,
  });

  final double xFactor;
  final double seed;
  final double speed;
  final double rotation;
  final double scale;
  final double drift;
}

class _MistBackground extends StatelessWidget {
  const _MistBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.2,
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.48),
            const Color(0xFF172554).withValues(alpha: 0.72),
            const Color(0xFF020617),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 80,
            left: -40,
            child: _MistBlob(
              size: 220,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -70,
            child: _MistBlob(size: 260, color: kBlue.withValues(alpha: 0.20)),
          ),
        ],
      ),
    );
  }
}

class _MistBlob extends StatelessWidget {
  const _MistBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DrawCard extends StatelessWidget {
  const _DrawCard({
    required this.active,
    required this.dimmed,
    this.width = 116,
    this.height = 168,
    this.badgeText,
  });

  final bool active;
  final bool dimmed;
  final double width;
  final double height;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: width,
      height: height,
      padding: EdgeInsets.all(width >= 116 ? 16 : 13),
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(width >= 116 ? 26 : 22),
        border: Border.all(
          color: active ? const Color(0xFF93C5FD) : Colors.white24,
          width: active ? 2.2 : 1,
        ),
        boxShadow: [
          if (active)
            const BoxShadow(
              color: Color(0x802563EB),
              blurRadius: 34,
              spreadRadius: 4,
            ),
        ],
      ),
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? Icons.auto_awesome_rounded : Icons.school_rounded,
              color: active ? kBlue : Colors.white70,
              size: width >= 116 ? 44 : 38,
            ),
            const SizedBox(height: 12),
            Text(
              active ? '错题卡' : 'AI题库',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? kInk : Colors.white70,
                fontSize: width >= 116 ? 16 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (active && badgeText != null) ...[
              const SizedBox(height: 6),
              Text(
                badgeText!,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 打卡成功专用对话框（精简）
class XpResultDialog extends StatelessWidget {
  const XpResultDialog({
    super.key,
    required this.settlement,
    required this.profile,
  });

  final XpSettlement settlement;
  final XpProfile profile;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('打卡成功'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('连续第 ${settlement.streak} 天，获得 ${settlement.finalXp} XP。',
              style: const TextStyle(height: 1.5)),
          const SizedBox(height: 14),
          _XpLine(label: '基础经验', value: '${settlement.baseXp} XP'),
          _XpLine(label: '倍率', value: '×${settlement.multiplier}'),
          _XpLine(label: '最终获得', value: '${settlement.finalXp} XP'),
          const Divider(height: 24),
          Text(
            '${_levelTitle(profile.level)} · Lv.${profile.level} · ${profile.totalXp} XP',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}

class _XpLine extends StatelessWidget {
  const _XpLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: kMuted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// 练习完成激励页：全屏动画 + 恭喜话术 + 经验值动画
class PracticeCompleteOverlay extends StatefulWidget {
  const PracticeCompleteOverlay({
    super.key,
    required this.settlement,
    required this.profile,
    required this.correct,
    required this.total,
    required this.isWrongCardChallenge,
  });

  final XpSettlement settlement;
  final XpProfile profile;
  final int correct;
  final int total;
  final bool isWrongCardChallenge;

  @override
  State<PracticeCompleteOverlay> createState() => _PracticeCompleteOverlayState();
}

class _PracticeCompleteOverlayState extends State<PracticeCompleteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _scaleCtrl;
  late final AnimationController _xpCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<int> _xpCount;
  late final Animation<double> _barFill;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _xpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    final finalXp = widget.settlement.finalXp;
    _xpCount = IntTween(begin: 0, end: finalXp).animate(
      CurvedAnimation(parent: _xpCtrl, curve: Curves.easeOutCubic),
    );
    _barFill = CurvedAnimation(parent: _xpCtrl, curve: Curves.easeOutCubic);

    // 启动动画序列
    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _scaleCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        HapticFeedback.mediumImpact();
        _xpCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _xpCtrl.dispose();
    super.dispose();
  }

  String _cheerText() {
    if (widget.total == 0) return '本轮已结束';
    final accuracy = widget.correct / widget.total;
    if (widget.isWrongCardChallenge) {
      if (accuracy >= 0.8) return '错题克星！温故而知新，太棒了！';
      if (accuracy >= 0.6) return '错题掌握得不错，继续加油！';
      return '错题还需要再练练，下次见！';
    }
    if (accuracy >= 0.9) return '太棒了！近乎满分的表现！';
    if (accuracy >= 0.7) return '不错的表现，继续保持！';
    if (accuracy >= 0.5) return '及格了，再接再厉！';
    return '别灰心，多练几次就有进步！';
  }

  String _emoji() {
    if (widget.total == 0) return '✨';
    final accuracy = widget.correct / widget.total;
    if (accuracy >= 0.9) return '🏆';
    if (accuracy >= 0.7) return '🌟';
    if (accuracy >= 0.5) return '💪';
    return '📚';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final accuracy = widget.total == 0
        ? 0.0
        : widget.correct / widget.total;
    final accent = accuracy >= 0.7
        ? kGreen
        : (accuracy >= 0.5 ? const Color(0xFFF97316) : kRed);

    return AnimatedBuilder(
      animation: Listenable.merge([_fade, _scale, _xpCtrl]),
      builder: (context, _) {
        return Material(
          color: Colors.black.withValues(alpha: 0.55 * _fade.value),
          child: InkWell(
            onTap: () => _dismiss(context),
            child: Container(
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Opacity(
                  opacity: _fade.value,
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * _scale.value,
                    child: _buildCard(context, accent, s),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, Color accent, XpSettlement s) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0.10), Colors.white],
            stops: const [0.0, 0.4],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部 emoji + 标题
            Text(
              _emoji(),
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isWrongCardChallenge ? '错题抽卡完成' : '练习完成',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _cheerText(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: kMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            // 正确率圆环
            _AccuracyRing(
              correct: widget.correct,
              total: widget.total,
              color: accent,
              progress: _scale.value,
            ),
            const SizedBox(height: 18),
            // XP 大数字（计数动画）
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${_xpCount.value}',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: kBlue,
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'XP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: kBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 经验条
            _XpProgress(
              profile: widget.profile,
              finalXp: s.finalXp,
              progress: _barFill.value,
            ),
            const SizedBox(height: 16),
            // 倍率提示
            if (s.multiplier > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '×${s.multiplier} 倍经验已生效',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF97316),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (s.boostActivated) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '三倍经验已开启，未来 10 分钟内有效',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF97316),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // 知道了按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _dismiss(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('继续努力'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dismiss(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.pop(context);
  }
}

/// 正确率圆环（带动画）
class _AccuracyRing extends StatelessWidget {
  const _AccuracyRing({
    required this.correct,
    required this.total,
    required this.color,
    required this.progress,
  });
  final int correct;
  final int total;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final accuracy = total == 0 ? 0.0 : correct / total;
    final pct = (accuracy * 100 * progress).round();
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CircularProgressIndicator(
              value: accuracy * progress,
              strokeWidth: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$correct / $total',
                style: const TextStyle(
                  fontSize: 11,
                  color: kMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 经验进度条（展示当前等级进度）
class _XpProgress extends StatelessWidget {
  const _XpProgress({
    required this.profile,
    required this.finalXp,
    required this.progress,
  });
  final XpProfile profile;
  final int finalXp;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // 每升一级需要 100 XP（XpProfile 内部规则）
    const span = 100;
    final before = (profile.totalXp - finalXp) % span;
    final after = profile.totalXp % span;
    final t = (before + (after - before) * progress) / span;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Lv.${profile.level}',
              style: const TextStyle(
                fontSize: 12,
                color: kMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _levelTitle(profile.level),
                style: const TextStyle(
                  fontSize: 12,
                  color: kMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${profile.totalXp} XP',
              style: const TextStyle(
                fontSize: 12,
                color: kMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(color: const Color(0xFFF1F5F9)),
                FractionallySizedBox(
                  widthFactor: t.clamp(0.0, 1.0),
                  child: Container(color: kBlue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key, required this.config, required this.onSave});

  final ApiConfig config;
  final ValueChanged<ApiConfig> onSave;

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late String _provider;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _baseCtrl;
  late final TextEditingController _modelCtrl;
  bool _testing = false;

  static const providers = {
    'deepseek': ('DeepSeek', 'https://api.deepseek.com', 'deepseek-v4-flash'),
    'qwen': (
      'Qwen',
      'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'qwen-plus',
    ),
    'zhipu': ('智谱', 'https://api.z.ai/api/paas/v4', 'glm-4.7-flash'),
    'mimo': ('小米 MiMo', 'https://api.xiaomimimo.com/v1', 'mimo-v2.5-pro'),
    'kimi': ('Kimi', 'https://api.moonshot.ai/v1', 'kimi-k2.6'),
    'custom': ('自定义', '', ''),
  };

  @override
  void initState() {
    super.initState();
    _provider = widget.config.provider;
    _keyCtrl = TextEditingController(text: widget.config.apiKey);
    _baseCtrl = TextEditingController(text: widget.config.baseUrl);
    _modelCtrl = TextEditingController(text: widget.config.model);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _baseCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _selectProvider(String key) {
    final provider = providers[key]!;
    setState(() {
      _provider = key;
      if (key != 'custom') {
        _baseCtrl.text = provider.$2;
        _modelCtrl.text = provider.$3;
      }
    });
  }

  Future<void> _test() async {
    final config = _currentConfig();
    if (!config.ready) {
      _snack('请完整填写 API Key、Base URL 和模型名称');
      return;
    }
    setState(() => _testing = true);
    try {
      await AiService.test(config);
      _snack('连接成功');
    } catch (error) {
      _snack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  ApiConfig _currentConfig() => ApiConfig(
    provider: _provider,
    apiKey: _keyCtrl.text.trim(),
    baseUrl: _baseCtrl.text.trim(),
    model: _modelCtrl.text.trim(),
  );

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _PageTitle(title: 'API 配置', subtitle: '安卓单体版直接从手机请求大模型，不需要外部后端。'),
        const SizedBox(height: 16),
        const Text(
          '选择服务商',
          style: TextStyle(fontWeight: FontWeight.w900, color: kMuted),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          children: providers.entries.map((entry) {
            final selected = entry.key == _provider;
            return InkWell(
              onTap: () => _selectProvider(entry.key),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? kBlue : kLine,
                    width: selected ? 2 : 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    entry.value.$1,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _keyCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'API Key',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baseCtrl,
          decoration: const InputDecoration(
            labelText: 'API Base URL',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _modelCtrl,
          decoration: const InputDecoration(
            labelText: '模型名称',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cable),
                label: const Text('测试连接'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  widget.onSave(_currentConfig());
                  _snack('配置已保存到本机');
                },
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _ApiGuideCard(),
        const SizedBox(height: 12),
        const _NoteCard(
          title: '本地化说明',
          body: '本 App 不提供账号系统，资料、API Key、练习记录都保存在当前手机。卸载 App 会删除这些本地数据。',
        ),
      ],
    );
  }
}

/// 可展开/收起的 API 配置教程，覆盖主流服务商。
class _ApiGuideCard extends StatefulWidget {
  const _ApiGuideCard();

  @override
  State<_ApiGuideCard> createState() => _ApiGuideCardState();
}

class _ApiGuideCardState extends State<_ApiGuideCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: kBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '如何获取 API Key？',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: kInk,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '第一次使用？点这里看完整图文教程',
                          style: TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    '本 App 支持 DeepSeek、通义千问、智谱 GLM、小米 MiMo、Kimi 等主流大模型 API。下面以 DeepSeek 为例（最常用且便宜），其他服务商步骤类似。',
                    style: TextStyle(color: kInk, height: 1.55),
                  ),
                  const SizedBox(height: 14),
                  _guideStep(
                    '1',
                    '打开 DeepSeek 官网',
                    '在浏览器中访问 platform.deepseek.com，注册或登录账号（支持微信/手机号登录）。',
                  ),
                  _guideStep(
                    '2',
                    '进入 API Keys 页面',
                    '登录成功后，在左侧菜单中点击「API keys」选项，进入密钥管理页面。',
                  ),
                  _guideStep(
                    '3',
                    '创建新的 API Key',
                    '点击页面中间的「创建 API key」红色按钮，在弹窗中随便起个名字（例如「题库」），然后点击「创建」。',
                  ),
                  _guideStep(
                    '4',
                    '复制 API Key',
                    '创建成功后会显示一串以 sk- 开头的长字符串，这就是你的 API Key。点击「复制」按钮将其复制到剪贴板。⚠️ 注意：这个 Key 只会显示一次，离开页面后就再也看不到了，请务必先复制保存好。',
                  ),
                  _guideStep(
                    '5',
                    '回到本 App 填写配置',
                    '① 在上方「API Key」输入框粘贴刚才复制的 Key\n'
                        '② 服务商选择「DeepSeek」（系统会自动填好 Base URL 和模型名）\n'
                        '③ 点击「测试连接」按钮，如果显示「连接成功」就可以点「保存配置」了',
                  ),
                  _guideStep(
                    '6',
                    '充值（按需）',
                    '新注册账号通常有少量免费额度可用于测试。如果用完了，需要在「费用」页面充值，充值 10 元即可做几百道题。',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_rounded,
                                color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 6),
                            Text(
                              '其他服务商入口',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• 通义千问：dashscope.console.aliyun.com\n'
                          '• 智谱 GLM：open.bigmodel.cn\n'
                          '• 小米 MiMo：mimo.xiaomi.com（提交申请）\n'
                          '• Kimi：platform.moonshot.cn',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideStep(String num, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: kBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(color: kMuted, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============ 试卷 PDF 生成服务 ============
///
/// 将模型可能返回的字符串、Map、labels/values 或对象数组统一成 PDF 可绘制数据。
Map<String, double> parsePdfChartData(dynamic rawData) {
  final result = <String, double>{};

  void add(dynamic rawLabel, dynamic rawValue) {
    final label = rawLabel.toString().trim();
    final value = rawValue is num
        ? rawValue.toDouble()
        : double.tryParse(rawValue.toString().replaceAll('%', '').trim());
    if (label.isEmpty || label.length > 16 || value == null || value < 0) return;
    result[label] = value;
  }

  if (rawData is Map) {
    final map = Map<dynamic, dynamic>.from(rawData);
    final labels = map['labels'];
    final values = map['values'];
    if (labels is List && values is List) {
      for (var i = 0; i < min(labels.length, values.length); i++) {
        add(labels[i], values[i]);
      }
    } else {
      for (final entry in map.entries) {
        if (entry.key == 'title' || entry.key == 'chart_type') continue;
        add(entry.key, entry.value);
      }
    }
  } else if (rawData is List) {
    for (final item in rawData) {
      if (item is Map) {
        final map = Map<dynamic, dynamic>.from(item);
        add(
          map['label'] ?? map['name'] ?? map['category'] ?? map['x'] ?? '',
          map['value'] ?? map['count'] ?? map['y'] ?? '',
        );
      } else if (item is List && item.length >= 2) {
        add(item[0], item[1]);
      }
    }
  } else {
    final normalized = rawData
        .toString()
        .replaceAll('：', ':')
        .replaceAll('＝', '=')
        .replaceAll('，', ',')
        .replaceAll('；', ',');
    final pairPattern = RegExp(
      r'([^,;:{}\[\]]{1,16}?)\s*[:=]\s*(-?\d+(?:\.\d+)?)\s*%?',
    );
    for (final match in pairPattern.allMatches(normalized)) {
      add(match.group(1)!, match.group(2)!);
    }
  }
  return result;
}

/// PDF 暂不直接执行 LaTeX；将常见公式转换为可打印的数学文本，避免输出源码。
String formatMathForPdf(String source) {
  var text = source
      .replaceAll(r'\[', '')
      .replaceAll(r'\]', '')
      .replaceAll(r'\(', '')
      .replaceAll(r'\)', '')
      .replaceAll(r'$$', '')
      .replaceAll(r'$', '')
      .trim();
  for (var i = 0; i < 4; i++) {
    text = text.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
      (match) => '(${match.group(1)})/(${match.group(2)})',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]+)\}'),
      (match) => '√(${match.group(1)})',
    );
  }
  const replacements = <String, String>{
    r'\lambda': 'λ',
    r'\mu': 'μ',
    r'\pi': 'π',
    r'\theta': 'θ',
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\Delta': 'Δ',
    r'\times': '×',
    r'\cdot': '·',
    r'\pm': '±',
    r'\leq': '≤',
    r'\le': '≤',
    r'\geq': '≥',
    r'\ge': '≥',
    r'\neq': '≠',
    r'\to': '→',
    r'\quad': ' ',
    r'\text': '',
    r'\mathrm': '',
    r'\mathbf': '',
    r'\left': '',
    r'\right': '',
  };
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  text = text
      .replaceAllMapped(RegExp(r'\^\{2\}'), (_) => '²')
      .replaceAllMapped(RegExp(r'\^\{3\}'), (_) => '³')
      .replaceAllMapped(RegExp(r'\^\{([^{}]+)\}'), (m) => '^(${m.group(1)})')
      .replaceAllMapped(RegExp(r'_\{([^{}]+)\}'), (m) => '_${m.group(1)}')
      .replaceAll(RegExp(r'[{}]'), '')
      .replaceAll(RegExp(r'\\[A-Za-z]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text;
}

/// 参考国内中考/高考/期末试卷排版：
/// - 装订线区（左侧竖向 班级/姓名/学号）
/// - 卷首标题区（学科 + 试卷名 + 学段·类型 + 满分/时间）
/// - 大题标题（一、单项选择题（每题X分，共X分））
/// - 题目与选项
/// - 主观题预留答题空白
/// - 页脚页码（第X页/共X页）
class PaperPdfService {
  PaperPdfService._();

  /// 生成试卷 PDF（不含答案）
  static Future<List<int>> buildPaperPdf(Paper paper) async {
    final doc = PdfDocument();
    _addPaperPages(doc, paper, withAnswer: false);
    return doc.save();
  }

  /// 生成答案 PDF（含答案与解析）
  static Future<List<int>> buildAnswerPdf(Paper paper) async {
    final doc = PdfDocument();
    _addPaperPages(doc, paper, withAnswer: true);
    return doc.save();
  }

  static void _addPaperPages(
    PdfDocument doc,
    Paper paper, {
    required bool withAnswer,
  }) {
    final pageWidth = PdfPageSize.a4.width;
    final pageHeight = PdfPageSize.a4.height;
    // 装订线区 70pt（约 2.5cm）
    const binding = 70.0;
    const marginLeft = binding + 20.0;
    const marginRight = 50.0;
    const marginTop = 50.0;
    const marginBottom = 50.0;

    // CJK 字体（华文宋体）
    final titleFont =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 22);
    final subTitleFont =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 12);
    final sectionFont =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 14);
    final bodyFont =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 11);
    final smallFont =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 10);
    final bindingFont =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 10);

    // 先创建第一页
    PdfPage page = doc.pages.add();
    PdfGraphics g = page.graphics;

    double y = marginTop;

    // 装订线（左侧竖线）
    g.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(binding, marginTop),
      Offset(binding, pageHeight - marginBottom),
    );

    // 装订线区文字（横向小字，画在装订线下方）
    g.drawString(
      '装\n订\n线',
      bindingFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(20, pageHeight / 2 - 30, 30, 60),
    );
    g.drawString(
      '班级\n姓名\n学号',
      bindingFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(35, pageHeight / 2 - 30, 30, 60),
    );

    // 卷首标题区
    // 主标题
    final title = '${paper.subject}试卷';
    g.drawString(
      title,
      titleFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(
          marginLeft, y, pageWidth - marginLeft - marginRight, 30),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 32;
    // 副标题
    g.drawString(
      paper.gradeLevel,
      subTitleFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(
          marginLeft, y, pageWidth - marginLeft - marginRight, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 18;
    // 满分/时间
    final totalScore = paper.totalScore;
    final metaLine =
        '（考试时间：${paper.pageCount * 20}分钟  满分：$totalScore 分）';
    g.drawString(
      metaLine,
      subTitleFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(
          marginLeft, y, pageWidth - marginLeft - marginRight, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 24;
    // 考生信息行（横排）
    g.drawString(
      '班级：________   姓名：________   学号：________   得分：________',
      bodyFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(
          marginLeft, y, pageWidth - marginLeft - marginRight, 18),
    );
    y += 22;
    // 分割线
    g.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 1),
        Offset(marginLeft, y),
        Offset(pageWidth - marginRight, y));
    y += 12;

    // 注意提示
    if (withAnswer) {
      g.drawString(
        '说明：本卷为答案与解析版，每题后附答案及解析。',
        smallFont,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(
            marginLeft, y, pageWidth - marginLeft - marginRight, 16),
      );
      y += 22;
    }

    // 按大题分组
    final sections = <String, List<PaperQuestion>>{};
    for (final q in paper.questions) {
      sections
          .putIfAbsent(q.section.isEmpty ? '题目' : q.section, () => [])
          .add(q);
    }

    final contentWidth = pageWidth - marginLeft - marginRight;

    int questionNum = 0;
    for (final sectionName in sections.keys) {
      final list = sections[sectionName]!;

      // 检查剩余空间，不够就换页
      if (y > pageHeight - marginBottom - 80) {
        _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
        page = doc.pages.add();
        g = page.graphics;
        // 装订线（新页）
        g.drawLine(
          PdfPen(PdfColor(0, 0, 0), width: 0.5),
          Offset(binding, marginTop),
          Offset(binding, pageHeight - marginBottom),
        );
        y = marginTop;
      }

      // 大题标题
      var sectionScore = 0;
      for (final q in list) {
        final t = q.question.type;
        if (t == 'choice' || t == 'multi_choice') {
          sectionScore += paper.scoreConfig.choiceScore;
        } else if (t == 'fill') {
          sectionScore += paper.scoreConfig.fillScore;
        } else if (t == 'true_false') {
          sectionScore += paper.scoreConfig.judgeScore;
        } else {
          sectionScore += paper.scoreConfig.subjectiveScore;
        }
      }
      final sectionTitle =
          '$sectionName（共 ${list.length} 题，$sectionScore 分）';
      g.drawString(
        sectionTitle,
        sectionFont,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(marginLeft, y, contentWidth, 22),
      );
      y += 26;

      // 题目
      for (final pq in list) {
        questionNum++;
        final q = pq.question;

        // 题干（手动换行：每行约 40 个中文字符宽）
        final qText = '$questionNum. ${q.question}  [${q.label}]';
        final lines = _wrapText(qText, 40);
        for (final line in lines) {
          if (y > pageHeight - marginBottom - 20) {
            _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
            page = doc.pages.add();
            g = page.graphics;
            g.drawLine(
              PdfPen(PdfColor(0, 0, 0), width: 0.5),
              Offset(binding, marginTop),
              Offset(binding, pageHeight - marginBottom),
            );
            y = marginTop;
          }
          g.drawString(
            line,
            bodyFont,
            brush: PdfBrushes.black,
            bounds: Rect.fromLTWH(marginLeft, y, contentWidth, 16),
          );
          y += 16;
        }
        y += 4;

        // 选项（选择题、判断题）
        if (q.options.isNotEmpty) {
          for (final opt in q.options) {
            if (y > pageHeight - marginBottom - 20) {
              _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
              page = doc.pages.add();
              g = page.graphics;
              g.drawLine(
                PdfPen(PdfColor(0, 0, 0), width: 0.5),
                Offset(binding, marginTop),
                Offset(binding, pageHeight - marginBottom),
              );
              y = marginTop;
            }
            g.drawString(
              '   $opt',
              bodyFont,
              brush: PdfBrushes.black,
              bounds: Rect.fromLTWH(
                  marginLeft + 14, y, contentWidth - 14, 16),
            );
            y += 16;
          }
          y += 4;
        }

        // v2.7.1: rich_content 图表信息（试卷版）
        // v2.7.6: chart 类型用 PdfGraphics 真正画图，不再降级为纯文字
        if (q.richContent.isNotEmpty) {
          for (final rc in q.richContent) {
            final rcType = (rc['type'] ?? '').toString();
            final rcData = rc['data'] is Map
                ? Map<String, dynamic>.from(rc['data'] as Map)
                : <String, dynamic>{};
            // v2.7.6: chart 类型直接在 PDF 中绘制图表
            if (rcType == 'chart') {
              var chartHeight = _drawChartInPdf(
                g, doc,
                marginLeft + 14, y,
                contentWidth - 14, 180,
                rcData,
                binding, marginTop, marginBottom, pageHeight, pageWidth,
              );
              // 若返回 -1 且是因为空间不够，换页后重试一次
              if (chartHeight < 0 && y > marginTop + 100) {
                _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
                page = doc.pages.add();
                g = page.graphics;
                g.drawLine(
                  PdfPen(PdfColor(0, 0, 0), width: 0.5),
                  Offset(binding, marginTop),
                  Offset(binding, pageHeight - marginBottom),
                );
                y = marginTop;
                chartHeight = _drawChartInPdf(
                  g, doc,
                  marginLeft + 14, y,
                  contentWidth - 14, 180,
                  rcData,
                  binding, marginTop, marginBottom, pageHeight, pageWidth,
                );
              }
              // 若仍失败（数据解析不出），降级为文字描述
              if (chartHeight > 0) {
                y += chartHeight + 8;
                continue;
              }
            }
            // 其他类型（math/physics/chemistry/svg/listening）继续用文字描述
            final desc = _richContentToText(rcType, rcData);
            if (desc.isEmpty) continue;
            final rcLines = _wrapText('  [$desc]', 40);
            for (final line in rcLines) {
              if (y > pageHeight - marginBottom - 20) {
                _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
                page = doc.pages.add();
                g = page.graphics;
                g.drawLine(
                  PdfPen(PdfColor(0, 0, 0), width: 0.5),
                  Offset(binding, marginTop),
                  Offset(binding, pageHeight - marginBottom),
                );
                y = marginTop;
              }
              g.drawString(
                line,
                smallFont,
                brush: PdfBrushes.gray,
                bounds: Rect.fromLTWH(
                    marginLeft + 14, y, contentWidth - 14, 14),
              );
              y += 14;
            }
            y += 2;
          }
          y += 2;
        }

        // 答案与解析（withAnswer 模式）
        if (withAnswer) {
          final ansLines = _wrapText('【答案】${q.answer}', 40);
          for (final line in ansLines) {
            if (y > pageHeight - marginBottom - 20) {
              _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
              page = doc.pages.add();
              g = page.graphics;
              g.drawLine(
                PdfPen(PdfColor(0, 0, 0), width: 0.5),
                Offset(binding, marginTop),
                Offset(binding, pageHeight - marginBottom),
              );
              y = marginTop;
            }
            g.drawString(
              line,
              smallFont,
              brush: PdfBrushes.black,
              bounds: Rect.fromLTWH(marginLeft, y, contentWidth, 14),
            );
            y += 14;
          }
          if (q.explanation.isNotEmpty) {
            final expLines = _wrapText('【解析】${q.explanation}', 40);
            for (final line in expLines) {
              if (y > pageHeight - marginBottom - 20) {
                _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
                page = doc.pages.add();
                g = page.graphics;
                g.drawLine(
                  PdfPen(PdfColor(0, 0, 0), width: 0.5),
                  Offset(binding, marginTop),
                  Offset(binding, pageHeight - marginBottom),
                );
                y = marginTop;
              }
              g.drawString(
                line,
                smallFont,
                brush: PdfBrushes.black,
                bounds: Rect.fromLTWH(marginLeft, y, contentWidth, 14),
              );
              y += 14;
            }
          }
          y += 6;
        } else if (q.type == 'subjective') {
          // 主观题预留答题空白（约 5 行横线）
          y += 6;
          for (var i = 0; i < 5; i++) {
            if (y > pageHeight - marginBottom - 20) {
              _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
              page = doc.pages.add();
              g = page.graphics;
              g.drawLine(
                PdfPen(PdfColor(0, 0, 0), width: 0.5),
                Offset(binding, marginTop),
                Offset(binding, pageHeight - marginBottom),
              );
              y = marginTop;
            }
            g.drawLine(
              PdfPen(PdfColor(180, 180, 180), width: 0.3),
              Offset(marginLeft + 14, y + 8),
              Offset(pageWidth - marginRight - 10, y + 8),
            );
            y += 16;
          }
          y += 4;
        }

        // 检查换页
        if (y > pageHeight - marginBottom - 60) {
          _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
          page = doc.pages.add();
          g = page.graphics;
          g.drawLine(
            PdfPen(PdfColor(0, 0, 0), width: 0.5),
            Offset(binding, marginTop),
            Offset(binding, pageHeight - marginBottom),
          );
          y = marginTop;
        }
      }
      y += 10;
    }

    // 卷末
    _drawPageNumber(g, page, pageWidth, pageHeight, doc.pages);
  }

  /// v2.7.6: 在 PDF 中绘制统计图表（柱状图/折线图/饼图/直方图）
  /// 使用 syncfusion_flutter_pdf 的 PdfGraphics 直接绘制原生图表
  /// 返回图表实际占用的高度，-1 表示绘制失败（数据不足）
  static double _drawChartInPdf(
    PdfGraphics g,
    PdfDocument doc,
    double x,
    double y,
    double width,
    double height,
    Map<String, dynamic> rcData,
    double binding,
    double marginTop,
    double marginBottom,
    double pageHeight,
    double pageWidth,
  ) {
    final rawChartType = (rcData['chart_type'] ?? 'bar').toString().toLowerCase();
    final chartType = rawChartType.contains('折') || rawChartType.contains('line')
        ? 'line'
        : rawChartType.contains('饼') ||
                rawChartType.contains('扇') ||
                rawChartType.contains('pie')
            ? 'pie'
            : rawChartType.contains('直方') || rawChartType.contains('histogram')
                ? 'histogram'
                : 'bar';
    final title = (rcData['title'] ?? '').toString();

    final dataMap = parsePdfChartData(rcData['data'] ?? rcData);
    if (dataMap.length < 2) return -1;

    // 如果空间不够，换页
    if (y > pageHeight - marginBottom - height - 30) {
      return -1; // 让外层换页后再次调用（实际上外层不会重试，但至少不画溢出）
    }

    // 配色方案（PdfColor 接受 0-255 整数）
    final colors = <PdfColor>[
      PdfColor(0, 115, 217),   // 蓝
      PdfColor(242, 115, 38),  // 橙
      PdfColor(51, 178, 77),    // 绿
      PdfColor(217, 51, 51),   // 红
      PdfColor(128, 77, 217),  // 紫
      PdfColor(242, 191, 26),  // 黄
      PdfColor(38, 166, 217), // 青
      PdfColor(178, 77, 128),  // 粉
    ];
    final chartTitleFont =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 11);
    final chartLabelFont =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 8);

    // 内边距：留出标题和坐标轴空间
    final chartX = x + 35;
    final chartY = y + 25;
    final chartW = width - 45;
    final chartH = height - 40;

    // 绘制标题
    if (title.isNotEmpty) {
      g.drawString(
        title,
        chartTitleFont,
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
        bounds: Rect.fromLTWH(x, y, width, 18),
      );
    }

    final entries = dataMap.entries.toList();
    final maxValue = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue == 0 ? 1.0 : maxValue;

    if (chartType == 'pie') {
      // 饼图：从 12 点钟方向开始，顺时针
      final total = entries.map((e) => e.value).fold(0.0, (a, b) => a + b);
      if (total == 0) return -1;
      final cx = x + width / 2;
      final cy = chartY + chartH / 2;
      final radius = chartW < chartH ? chartW / 2 : chartH / 2;
      var startAngle = -90.0; // 从 12 点开始
      for (var i = 0; i < entries.length; i++) {
        final sweepAngle = (entries[i].value / total) * 360;
        g.drawPie(
          Rect.fromLTWH(cx - radius, cy - radius, radius * 2, radius * 2),
          startAngle,
          sweepAngle,
          brush: PdfSolidBrush(colors[i % colors.length]),
          pen: PdfPen(PdfColor(255, 255, 255), width: 1),
        );
        startAngle += sweepAngle;
      }
      // 图例
      var legendY = chartY + chartH + 5;
      var legendX = x + 5.0;
      for (var i = 0; i < entries.length; i++) {
        // 色块
        g.drawRectangle(
          bounds: Rect.fromLTWH(legendX, legendY, 10, 10),
          brush: PdfSolidBrush(colors[i % colors.length]),
        );
        // 标签
        final labelText = '${entries[i].key}: ${_fmtNum(entries[i].value)}';
        g.drawString(
          labelText,
          chartLabelFont,
          brush: PdfSolidBrush(PdfColor(26, 26, 26)),
          bounds: Rect.fromLTWH(legendX + 12, legendY, 80, 10),
        );
        legendX += 12 + labelText.length * 5 + 10;
        if (legendX > x + width - 90) {
          legendX = x + 5.0;
          legendY += 14;
        }
      }
    } else if (chartType == 'line') {
      // 折线图
      // 坐标轴
      g.drawLine(PdfPen(PdfColor(51, 51, 51), width: 0.5),
          Offset(chartX, chartY), Offset(chartX, chartY + chartH));
      g.drawLine(PdfPen(PdfColor(51, 51, 51), width: 0.5),
          Offset(chartX, chartY + chartH), Offset(chartX + chartW, chartY + chartH));
      // 数据点
      final stepX = chartW / (entries.length - 1).clamp(1, entries.length - 1);
      var prevX = chartX;
      var prevY = chartY + chartH - (entries[0].value / safeMax) * chartH;
      // 画第一个点
      g.drawEllipse(
        Rect.fromLTWH(prevX - 2.5, prevY - 2.5, 5, 5),
        brush: PdfSolidBrush(colors[0]),
      );
      // X 轴标签 + 折线
      for (var i = 1; i < entries.length; i++) {
        final px = chartX + i * stepX;
        final py = chartY + chartH - (entries[i].value / safeMax) * chartH;
        // 线
        g.drawLine(
          PdfPen(colors[i % colors.length], width: 2),
          Offset(prevX, prevY),
          Offset(px, py),
        );
        // 点
        g.drawEllipse(
          Rect.fromLTWH(px - 2.5, py - 2.5, 5, 5),
          brush: PdfSolidBrush(colors[i % colors.length]),
        );
        // X 轴标签
        g.drawString(
          entries[i].key,
          chartLabelFont,
          brush: PdfSolidBrush(PdfColor(77, 77, 77)),
          bounds: Rect.fromLTWH(px - 15, chartY + chartH + 3, 30, 10),
        );
        prevX = px;
        prevY = py;
      }
      // 第一个 X 轴标签
      g.drawString(
        entries[0].key,
        chartLabelFont,
        brush: PdfSolidBrush(PdfColor(77, 77, 77)),
        bounds: Rect.fromLTWH(chartX - 15, chartY + chartH + 3, 30, 10),
      );
    } else {
      // 柱状图 / 直方图（统一处理）
      // 坐标轴
      g.drawLine(PdfPen(PdfColor(51, 51, 51), width: 0.5),
          Offset(chartX, chartY), Offset(chartX, chartY + chartH));
      g.drawLine(PdfPen(PdfColor(51, 51, 51), width: 0.5),
          Offset(chartX, chartY + chartH), Offset(chartX + chartW, chartY + chartH));
      // 柱子
      final barWidth = (chartW / entries.length) * 0.6;
      final barGap = (chartW / entries.length) * 0.4;
      for (var i = 0; i < entries.length; i++) {
        final bx = chartX + i * (barWidth + barGap) + barGap / 2;
        final bh = (entries[i].value / safeMax) * chartH;
        final by = chartY + chartH - bh;
        g.drawRectangle(
          bounds: Rect.fromLTWH(bx, by, barWidth, bh),
          brush: PdfSolidBrush(colors[i % colors.length]),
          pen: PdfPen(PdfColor(51, 51, 51), width: 0.3),
        );
        // 数值标签
        g.drawString(
          _fmtNum(entries[i].value),
          chartLabelFont,
          brush: PdfSolidBrush(PdfColor(26, 26, 26)),
          bounds: Rect.fromLTWH(bx - 5, by - 12, barWidth + 10, 10),
        );
        // X 轴标签
        g.drawString(
          entries[i].key,
          chartLabelFont,
          brush: PdfSolidBrush(PdfColor(77, 77, 77)),
          bounds: Rect.fromLTWH(bx - 5, chartY + chartH + 3, barWidth + 10, 10),
        );
      }
    }

    return height;
  }

  /// v2.7.6: 格式化数字（整数去 .0，小数保留 1 位）
  static String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  /// v2.7.1: 将 rich_content 转为 PDF 中的文本描述
  static String _richContentToText(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'math':
        final content = (data['content'] ?? '').toString().trim();
        if (content.contains('[graph:')) {
          return '函数关系：${formatMathForPdf(content.replaceAll('[graph:', '').replaceAll(']', '').trim())}';
        }
        final printable = formatMathForPdf(content);
        return printable.isEmpty ? '数学公式' : '数学公式：$printable';
      case 'chart':
        final chartType = (data['chart_type'] ?? '统计图').toString();
        final title = (data['title'] ?? '').toString();
        return '${title.isEmpty ? '' : '$title - '}$chartType（图表数据暂不可绘制）';
      case 'physics':
        final diagramType = (data['diagram_type'] ?? '物理图').toString();
        final params = (data['params'] ?? '').toString();
        return '物理示意图：$diagramType（$params）';
      case 'chemistry':
        final diagramType = (data['diagram_type'] ?? '化学结构').toString();
        final params = (data['params'] ?? '').toString();
        return '化学结构：$diagramType（$params）';
      case 'svg':
        return 'SVG 图形';
      case 'listening':
        final audioText = (data['audio_text'] ?? '').toString().trim();
        final voice = (data['voice'] ?? 'en-US').toString();
        return '听力题（$voice）：$audioText';
      default:
        return '';
    }
  }

  /// 简单文本换行：按字符数切分
  static List<String> _wrapText(String text, int charsPerLine) {
    final result = <String>[];
    final buf = StringBuffer();
    var count = 0;
    for (final ch in text.characters) {
      buf.write(ch);
      count++;
      // 全角字符算 2，半角算 1
      final isHalfWidth = ch.codeUnitAt(0) < 128;
      if (!isHalfWidth) count++;
      if (count >= charsPerLine * 2) {
        result.add(buf.toString());
        buf.clear();
        count = 0;
      }
    }
    if (buf.isNotEmpty) result.add(buf.toString());
    return result.isEmpty ? [''] : result;
  }

  static void _drawPageNumber(PdfGraphics g, PdfPage currentPage,
      double pageWidth, double pageHeight, PdfPageCollection pages) {
    final total = pages.count;
    final current = pages.indexOf(currentPage) + 1;
    final font =
        PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 10);
    g.drawString(
      '第 $current 页 / 共 $total 页',
      font,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(0, pageHeight - 30, pageWidth, 16),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
  }
}

class AiService {
  static Future<void> test(ApiConfig config) async {
    await _chat(config, [
      {'role': 'user', 'content': '请只回复 OK'},
    ], maxTokens: 8);
  }

  static Future<List<AiQuestion>> generateQuestions({
    required ApiConfig config,
    required String material,
    required List<String> types,
    required int count,
    required String audience,
    bool enableRichContent = false,
    bool enableListening = false,
  }) async {
    final typeText = types.map(_typeLabel).join('、');
    final richTarget = richContentTargetCount(count);
    final materialText = material.length > 6500
        ? material.substring(0, 6500)
        : material;
    // v2.7.5: 当 enableListening=true 时，即使 enableRichContent=false 也必须允许 listening 块
    // listening 是 rich_content 数组的一种类型，不能被纯文字模式禁掉
    final richRequireBlock = enableRichContent
        ? '''6. **rich_content 启用**：当题目涉及以下情况时**必须**返回 rich_content 数组：
   - 数学公式（含分式、根号、上下标、求和、积分等）→ type:"math"，content 用 \$\$...\$\$
   - 函数图像（一次/二次/三角/指数等）→ type:"math"，content 用 [graph: f(x)=...]
   - 统计图（柱状/折线/饼图）→ type:"chart"，data.chart_type + data.data
   - 物理受力/电路/光路等示意图 → type:"physics"
   - 化学分子结构/反应方程 → type:"chemistry"${enableListening ? '''
   - 英语听力原文 → type:"listening"（仅英语学科使用，audio_text 必填）''' : ''}
   普通纯文字题目可留空数组 []。
   例：{"type":"math","data":{"content":"\$\$x^2 + y^2 = r^2\$\$"}}

注意：上例中 \$\$ 是 LaTeX 公式分隔符，不要解析为变量。'''
        : enableListening
            ? '6. 本次为纯文字题目模式，**不要返回 math/physics/chemistry/chart/svg 等 rich_content**；但**英语听力题的 listening 块例外**，必须按第 8 条要求返回 listening rich_content。'
            : '6. 本次为纯文字题目模式，不要返回 rich_content 字段或留空数组 []，避免拖长输出导致 JSON 截断。';
    final chartNote = enableRichContent
        ? '\n8. **图表题配额（强制）**：总共 $count 道题中，必须恰好有 $richTarget 道题包含 type:"chart" 的 rich_content（约 25%，必须保持在 20%-30%）。chart.data 必须是与题干一致的真实数据，格式为“标签:数值,标签:数值”，至少 2 组；其余题目不得返回 chart。'
        : '\n8. 本次不开启图表题，不要返回 chart 类型。';
    final listeningNote = enableListening
        ? '\n9. **听力题配额（强制）**：总共 $count 道题中，必须恰好有 $richTarget 道题包含 type:"listening" 的 rich_content（约 25%，必须保持在 20%-30%）。\n   - listening 块格式：{"type":"listening","data":{"audio_text":"完整可朗读段落（30-80 词，来自资料或基于资料改编，不要只截取零散词语）","voice":"en-US 或 zh-CN"}}\n   - audio_text 必须是完整句子或段落，各题不得重复\n   - 若图表和听力同时开启，两类各占约 25%，不要放在同一道题中'
        : '\n9. 本次不生成听力题（音频开关已关闭）。';
    final prompt = enableRichContent
        ? '''
请基于下面学习资料生成 $count 道题，目标群体：$audience。
题型范围：$typeText。

严格只返回 JSON，不要 Markdown，不要解释。JSON 格式如下：
[
  {
    "question_type": "choice | multi_choice | true_false | fill | subjective",
    "question": "题干",
    "options": ["A. 选项", "B. 选项"],
    "answer": "A 或 [\\"A\\",\\"C\\"] 或 正确/错误 或 填空答案",
    "explanation": "解析",
    "rich_content": []
  }
]

要求：
1. 单选题必须有 4 个选项，答案为 A/B/C/D。
2. 多选题必须有 4 个选项，答案为数组。
3. 判断题 options 可为 ["正确","错误"]。
4. 填空题和主观题 options 为空数组。
5. question_type 必须使用：${types.join(',')}。
$richRequireBlock
7. 涉及图形/公式的题目，**禁止**在题干中使用"如图所示"等无法表达的描述，必须通过 rich_content 字段返回对应的图形描述。
$chartNote
$listeningNote

学习资料：
$materialText
'''
        : '''
请基于下面学习资料生成 $count 道题，目标群体：$audience。
题型范围：$typeText。

严格只返回 JSON，不要 Markdown，不要解释。JSON 格式如下：
[
  {
    "question_type": "choice | multi_choice | true_false | fill | subjective",
    "question": "题干",
    "options": ["A. 选项", "B. 选项"],
    "answer": "A 或 [\\"A\\",\\"C\\"] 或 正确/错误 或 填空答案",
    "explanation": "解析"${enableListening ? '''
    ,"rich_content": []  // 仅英语听力题填 listening 块，其他题目留空数组''' : ''}
  }
]

要求：
1. 单选题必须有 4 个选项，答案为 A/B/C/D。
2. 多选题必须有 4 个选项，答案为数组。
3. 判断题 options 可为 ["正确","错误"]。
4. 填空题和主观题 options 为空数组。
5. question_type 必须使用：${types.join(',')}。
$richRequireBlock
$chartNote
$listeningNote

学习资料：
$materialText
''';
    final content = await _chat(
      config,
      [
        {'role': 'system', 'content': '你是严谨的中文学习题库出题助手，只输出可解析 JSON。'},
        {'role': 'user', 'content': prompt},
      ],
      maxTokens: (count * 500).clamp(4500, 12000),
    );
    final jsonText = _extractJson(content);
    final decoded = jsonDecode(jsonText);
    final list = decoded is List
        ? decoded
        : decoded['questions'] as List? ?? [];
    final questions = list
        .map(
          (item) => AiQuestion.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .where((q) => q.question.trim().isNotEmpty)
        .toList();
    // v2.7.1 听力题兜底：若 enableListening=true 且资料含较多英文，
    // 但 AI 未生成任何 listening 题，强制改造第一道题为听力题
    if (enableListening && questions.isNotEmpty) {
      _ensureListeningFallback(questions, materialText);
    }
    _capRichContentType(
      questions,
      type: 'chart',
      target: enableRichContent ? richTarget : 0,
    );
    _capRichContentType(
      questions,
      type: 'listening',
      target: enableListening ? richTarget : 0,
    );
    return questions;
  }

  /// v2.8.0: 闯关 RPG 出题
  /// 按学科章节和关卡难度生成题目：
  /// - 关卡 1-2：简单（基础概念题）
  /// - 关卡 3-4：中等（应用题）
  /// - 关卡 5：Boss（4 基础 + 1 综合大题）
  /// AI 即时生成，不缓存，每次闯关都是全新题目
  static Future<List<AiQuestion>> generateRpgQuestions({
    required ApiConfig config,
    required String material,
    required String subject,
    required int chapter,
    required int level,
    String audience = '通用',
  }) async {
    final materialText = material.length > 6500
        ? material.substring(0, 6500)
        : material;
    final isBoss = level == 5;
    final difficultyDesc = level <= 2
        ? '简单（基础概念、定义识别、直接套用公式）'
        : level <= 4
            ? '中等（应用题、综合判断、需多步推理）'
            : '困难（综合大题、跨知识点整合、需深度分析）';
    // Boss 关：4 道基础 + 1 道综合大题
    final typeSpec = isBoss
        ? '前 4 道为选择题（choice），第 5 道为综合主观题（subjective，需 100-200 字论述）'
        : '选择 3 题 + 填空 2 题（choice / fill）';
    final chapterInfo = _rpgChaptersForSubject(subject);
    final chTitle = chapterInfo.length >= chapter
        ? chapterInfo[chapter - 1].title
        : '第${chapter}章';

    final prompt = '''请基于下面学习资料生成闯关 RPG 题目。
学科：$subject
章节：$chTitle
关卡：第 $level 关（Boss 关 = $isBoss）
难度：$difficultyDesc
目标群体：$audience
题型要求：$typeSpec

严格只返回 JSON 数组，不要 Markdown，不要解释。JSON 格式：
[
  {
    "question_type": "choice | fill | subjective",
    "question": "题干",
    "options": ["A. 选项", "B. 选项", "C. 选项", "D. 选项"],
    "answer": "A 或 填空答案 或 主观题参考答案",
    "explanation": "详细解析",
    "knowledge_point": "知识点（如：一元二次方程）",
    "rich_content": []
  }
]

要求：
1. 单选题必须有 4 个选项，答案为 A/B/C/D。
2. 填空题 options 为空数组。
3. 主观题（仅 Boss 关第 5 题）options 为空数组，answer 为参考答案要点。
4. knowledge_point 必填，简短 2-8 字。
5. 题目必须紧扣资料内容，难度符合关卡设定。
6. 第 ${level == 5 ? '1-4 题为基础难度，第 5 题为综合大题' : '所有题目难度一致'}。
7. 不要返回 rich_content 字段，留空数组 []。

学习资料：
$materialText
''';
    final content = await _chat(
      config,
      [
        {'role': 'system', 'content': '你是严谨的中文学习题库出题助手，专长是按难度梯度生成闯关题目，只输出可解析 JSON。'},
        {'role': 'user', 'content': prompt},
      ],
      maxTokens: isBoss ? 8000 : 5000,
    );
    final jsonText = _extractJson(content);
    final decoded = jsonDecode(jsonText);
    final list = decoded is List
        ? decoded
        : decoded['questions'] as List? ?? [];
    final questions = list
        .map(
          (item) => AiQuestion.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .where((q) => q.question.trim().isNotEmpty)
        .toList();
    return isBoss ? questions.take(5).toList() : questions.take(5).toList();
  }

  /// v2.9.0: 生成 Mini-Game 闯关题目
  /// 根据学科和关卡自动选择 mini-game 类型组合，每关固定 5 个 mini-game
  static Future<List<MiniGame>> generateMiniGames({
    required ApiConfig config,
    required String material,
    required String subject,
    required int chapter,
    required int level,
    String audience = '通用',
  }) async {
    final materialText = material.length > 6500
        ? material.substring(0, 6500)
        : material;
    final isBoss = level == 5;
    final difficultyDesc = level <= 2
        ? '简单（基础概念、定义识别）'
        : level <= 4
            ? '中等（应用题、综合判断）'
            : '困难（跨知识点整合、深度分析）';
    final chapterInfo = _rpgChaptersForSubject(subject);
    final chTitle = chapterInfo.length >= chapter
        ? chapterInfo[chapter - 1].title
        : '第${chapter}章';

    // 每个关卡固定 5 个互动题，第 5 关为难度明显提升的 Boss 关。
    const gameCount = 5;
    final selectedTypes = rpgMiniGameTypesFor(
      subject: subject,
      chapter: chapter,
      level: level,
      count: gameCount,
    );

    final prompt = '''请基于下面学习资料生成闯关 RPG 的 Mini-Game 题目。
学科：$subject
章节：$chTitle
关卡：第 $level 关（Boss 关 = $isBoss）
难度：$difficultyDesc
目标群体：$audience

本次需要生成 $gameCount 个 Mini-Game，类型分别为：${selectedTypes.map((t) {
      switch (t) {
        case 'matching': return 'matching(配对匹配)';
        case 'listening': return 'listening(听力选择)';
        case 'flashcard': return 'flashcard(闪卡记忆)';
        case 'reorder': return 'reorder(顺序排列)';
        case 'tapfast': return 'tapfast(限时快选)';
        case 'spell': return 'spell(单词拼写)';
        case 'fillblank': return 'fillblank(填空拼图)';
        case 'truefalse': return 'truefalse(真假快判)';
        case 'linkup': return 'linkup(连连看)';
        default: return t;
      }
    }).join('、')}

严格只返回 JSON 数组，不要 Markdown，不要解释。每种类型的格式：

1. matching（配对匹配）：
{"game_type":"matching","prompt":"将左侧术语与右侧定义配对","pairs":[{"left":"术语1","right":"定义1"},{"left":"术语2","right":"定义2"},{"left":"术语3","right":"定义3"},{"left":"术语4","right":"定义4"}],"explanation":"本组知识点概述","knowledge_point":"知识点"}

2. flashcard（闪卡记忆）：
{"game_type":"flashcard","prompt":"先看闪卡内容记住，然后回答问题","options":["闪卡正面内容（公式/概念/定义）"],"answer":"针对闪卡内容的一道选择题答案（A/B/C/D）","explanation":"解析","knowledge_point":"知识点"}
注意：flashcard 的 options[0] 是闪卡展示内容，prompt 是闪卡看完后的问题（含4个选项写在prompt里）

4. reorder（顺序排列）：
{"game_type":"reorder","prompt":"将以下步骤排列成正确顺序（题干描述任务）","options":["步骤1（已打乱）","步骤2","步骤3","步骤4"],"answer":"0,2,1,3","explanation":"解析","knowledge_point":"知识点"}
注意：answer 是正确顺序的索引（从0开始，逗号分隔），options 是打乱后的

5. tapfast（限时快选）：
{"game_type":"tapfast","prompt":"快速判断以下陈述是否正确（限时15秒）","options":["陈述1","陈述2","陈述3","陈述4","陈述5","陈述6"],"answer":"对,错,对,错,对,错","explanation":"解析","knowledge_point":"知识点"}
注意：answer 用 对/错 标记每个陈述的正误，options 数量与 answer 一致

6. spell（单词拼写）：
{"game_type":"spell","prompt":"根据提示拼出正确单词/术语（clue：定义或线索）","answer":"photosynthesis","options":[],"explanation":"解析","knowledge_point":"知识点"}
注意：answer 是要拼的单词或中文术语（2-10个字符）；英文单词须来自资料；中文术语可用2-6个汉字；options 留空（系统自动打乱字母/字）

7. fillblank（填空拼图）：
{"game_type":"fillblank","prompt":"题干句子，用 ___ 表示挖空处","options":["词1(含正确答案和干扰项)","词2","词3","词4"],"answer":"正确填入的词","explanation":"解析","knowledge_point":"知识点"}
注意：prompt 中用 ___ 标记挖空位置（可多个空），options 是候选词库（含正确答案+3个干扰词），answer 是正确词

8. truefalse（真假快判）：
{"game_type":"truefalse","prompt":"一个需要判断对错的陈述句","answer":"对","options":[],"explanation":"解析","knowledge_point":"知识点"}
注意：answer 只能是 对 或 错；prompt 是单个陈述；options 留空

9. linkup（连连看）：
{"game_type":"linkup","prompt":"点击配对消除：找出相关的两组内容","pairs":[{"left":"概念1","right":"对应1"},{"left":"概念2","right":"对应2"},{"left":"概念3","right":"对应3"}],"explanation":"解析","knowledge_point":"知识点"}
注意：pairs 3-4 组，left 与 right 配对，内容来自资料知识点

要求：
1. 每种类型的字段必须完整。
2. matching/linkup 的 pairs 必须 3-4 组，左右内容不能重复。
3. 不得返回 listening（听力）类型；听力题仅用于普通出题和试卷模式。
4. reorder 的 answer 必须是打乱后到正确顺序的索引映射。
5. tapfast 的 options 至少 4 个陈述，answer 用 对/错 标记。
6. spell 的 answer 是要拼的单词/术语（2-10字符），options 留空。
7. fillblank 的 prompt 用 ___ 标记空位，options 含正确答案+干扰词。
8. truefalse 的 answer 只能是 对 或 错，options 留空。
9. knowledge_point 简短 2-8 字。
10. 题目必须紧扣资料内容，难度符合关卡设定。
11. Boss 关（第5关）题目需综合、有挑战性。

学习资料：
$materialText
''';
    final content = await _chat(
      config,
      [
        {'role': 'system', 'content': '你是游戏化学习设计专家，擅长把知识点改造成有趣的 Mini-Game。只输出可解析 JSON 数组。'},
        {'role': 'user', 'content': prompt},
      ],
      maxTokens: isBoss ? 8000 : 6000,
    );
    final jsonText = _extractJson(content);
    final decoded = jsonDecode(jsonText);
    final list = decoded is List
        ? decoded
        : decoded['games'] as List? ?? [];
    final games = list
        .map((item) => MiniGame.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((g) =>
            g.prompt.trim().isNotEmpty &&
            g.type != MiniGameType.listening &&
            selectedTypes.contains(g.type.name))
        .toList();
    // 兜底：模型偶尔少返回题目时，用资料片段补齐，保证每关完整 5 题。
    if (games.length < gameCount) {
      final completed = [...games];
      final fallback = _generateFallbackMiniGames(
        material,
        subject,
        level,
        gameCount,
      );
      var index = 0;
      while (completed.length < gameCount && fallback.isNotEmpty) {
        completed.add(fallback[index % fallback.length]);
        index++;
      }
      return completed.take(gameCount).toList();
    }
    return games.take(gameCount).toList();
  }

  /// v2.9.0: 兜底 mini-game 生成（AI 失败时）
  static List<MiniGame> _generateFallbackMiniGames(String material, String subject, int level, int count) {
    final sentences = material
        .split(RegExp(r'[。.!！\n]'))
        .map((s) => s.trim())
        .where((s) => s.length > 8 && s.length < 60)
        .take(8)
        .toList();
    final games = <MiniGame>[];
    var idx = 0;
    // 至少一个 matching
    if (sentences.length >= 4) {
      final lefts = sentences.sublist(0, 4).toList();
      final rights = lefts.reversed.toList();
      games.add(MiniGame(
        type: MiniGameType.matching,
        prompt: '将左侧与右侧配对',
        options: lefts,
        answer: rights.join('^A'),
        knowledgePoint: '资料要点',
      ));
      idx = 4;
    }
    // 一个 tapfast
    if (sentences.length >= idx + 4) {
      final opts = sentences.sublist(idx, idx + 4).toList();
      games.add(MiniGame(
        type: MiniGameType.tapfast,
        prompt: '快速判断以下陈述是否正确',
        options: opts,
        answer: '对,对,对,对',
        knowledgePoint: '资料要点',
      ));
    }
    // 极短资料也至少生成一个可玩的判断题，后续再补齐到 5 题。
    if (games.isEmpty) {
      final snippet = material.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (snippet.isNotEmpty) {
        games.add(MiniGame(
          type: MiniGameType.truefalse,
          prompt: snippet.length > 80 ? snippet.substring(0, 80) : snippet,
          options: const [],
          answer: '对',
          knowledgePoint: subject == '通用' ? '资料要点' : subject,
        ));
      }
    }
    // 补齐到 count
    while (games.length < count && games.isNotEmpty) {
      games.add(games.first);
    }
    return games.take(count).toList();
  }

  /// 将某类富内容限制到目标数量，防止模型忽略配额后生成过多图表/听力题。
  static void _capRichContentType(
    List<AiQuestion> questions, {
    required String type,
    required int target,
  }) {
    var retained = 0;
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final blocks = <Map<String, dynamic>>[];
      var changed = false;
      for (final block in q.richContent) {
        final blockType = (block['type'] ?? '').toString().toLowerCase();
        if (blockType == type) {
          if (retained >= target) {
            changed = true;
            continue;
          }
          retained++;
        }
        blocks.add(block);
      }
      if (changed) {
        questions[i] = AiQuestion(
          type: q.type,
          question: q.question,
          options: q.options,
          answer: q.answer,
          explanation: q.explanation,
          richContent: blocks,
        );
      }
    }
  }

  static void _capPaperRichContentType(
    List<PaperQuestion> questions, {
    required String type,
    required int target,
  }) {
    final normalized = questions.map((item) => item.question).toList();
    _capRichContentType(normalized, type: type, target: target);
    for (var i = 0; i < questions.length; i++) {
      final item = questions[i];
      if (identical(item.question, normalized[i])) continue;
      questions[i] = PaperQuestion(
        section: item.section,
        indexInSection: item.indexInSection,
        question: normalized[i],
        knowledgePoint: item.knowledgePoint,
      );
    }
  }

  /// v2.9.8 听力题兜底：若开关开启且模型返回不足，补齐到总题数约 25%。
  /// v2.7.5: 放宽英文片段提取条件——从 30-200字符/6词 降到 15-300字符/4词
  ///         并新增题干英文兜底（AI 出题时题干里可能含英文短语）
  static void _ensureListeningFallback(
    List<AiQuestion> questions,
    String material,
  ) {
    if (questions.isEmpty) return;
    final targetCount = richContentTargetCount(questions.length);
    final existingListening = questions.where((q) => q.richContent.any(
          (rc) => (rc['type'] ?? '').toString() == 'listening',
        )).length;
    if (existingListening >= targetCount) return;
    // 计算英文（拉丁字母）比例
    final latinCount = RegExp(r'[A-Za-z]').allMatches(material).length;
    final totalChars = material.replaceAll(RegExp(r'\s'), '').length;
    if (totalChars == 0 || latinCount / totalChars < 0.05) return;
    // v2.7.5: 放宽正则——15-300字符，至少4个连续单词的英文片段
    // 注意：用双引号 raw string，字符类里去掉 " 避免冲突
    final englishMatches =
        RegExp(r"[A-Za-z][A-Za-z\s,.!?\-';:()]{14,300}").allMatches(material);
    var englishSegments = englishMatches
        .map((m) => m.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((s) => s.split(RegExp(r'\s+')).length >= 4) // v2.7.5: 至少 4 个单词
        .toList();
    // v2.7.5: 若资料里英文片段不够，从题目题干中再提取一次
    if (englishSegments.length < targetCount) {
      for (final q in questions) {
        final qMatches =
            RegExp(r"[A-Za-z][A-Za-z\s,.!?\-';:()]{14,300}").allMatches(q.question);
        for (final m in qMatches) {
          final seg = m.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (seg.split(RegExp(r'\s+')).length >= 4 &&
              !englishSegments.contains(seg)) {
            englishSegments.add(seg);
          }
        }
      }
    }
    if (englishSegments.isEmpty) return;
    final need = (targetCount - existingListening).clamp(0, questions.length);
    var segIdx = 0;
    // v2.7.4: 从非听力题开始改造，避免重复
    final candidateIndices = <int>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (!q.richContent.any((rc) => (rc['type'] ?? '') == 'listening')) {
        candidateIndices.add(i);
      }
    }
    var applied = 0;
    for (final i in candidateIndices) {
      if (applied >= need) break;
      final q = questions[i];
      final audioText = englishSegments[segIdx % englishSegments.length];
      segIdx++;
      final newRich = <Map<String, dynamic>>[
        ...q.richContent,
        {
          'type': 'listening',
          'data': {
            'audio_text': audioText,
            'voice': 'en-US',
          },
        },
      ];
      questions[i] = AiQuestion(
        type: q.type,
        question: q.question,
        options: q.options,
        answer: q.answer,
        explanation: q.explanation,
        richContent: newRich,
      );
      applied++;
      debugPrint('[RichContent] 听力题兜底：第 ${i + 1} 题追加 listening 块（${audioText.split(RegExp(r'\s+')).length} 词）');
    }
  }

  /// 生成整套试卷（参考国内期末/期中/中高考模板）
  ///
  /// [template] 指定题型分布模板；为 null 时按 pageCount 自动推算。
  static Future<List<PaperQuestion>> generatePaper({
    required ApiConfig config,
    required String material,
    required String subject,
    required String gradeLevel,
    required int pageCount,
    PaperScoreConfig scoreConfig = const PaperScoreConfig(),
    PaperTemplate? template,
    bool enableRichContent = true,
    bool enableListening = false,
    String chapterRange = '',
    String knowledgePointSpec = '',
    int listeningCount = 0,
  }) async {
    final materialText =
        material.length > 8000 ? material.substring(0, 8000) : material;

    // 选择题型分布：优先使用显式模板；否则按默认规则
    final tpl = template ?? PaperTemplate.defaultFor(
      subject: subject,
      gradeLevel: gradeLevel,
      pageCount: pageCount,
    );

    final cs = scoreConfig.choiceScore;
    final fs = scoreConfig.fillScore;
    final js = scoreConfig.judgeScore;
    final ss = scoreConfig.subjectiveScore;
    final totalLine = scoreConfig.effectiveTotal > 0
        ? '（满分 ${scoreConfig.effectiveTotal} 分）'
        : '（满分 = 各题型分值之和）';

    // 构建大题描述
    final sections = <String>[];
    if (tpl.choiceCount > 0) {
      sections.add('一、单项选择题（共 ${tpl.choiceCount} 题，每题 $cs 分）');
    }
    if (tpl.fillCount > 0) {
      sections.add('二、填空题（共 ${tpl.fillCount} 题，每空 $fs 分）');
    }
    if (tpl.judgeCount > 0) {
      sections.add('三、判断题（共 ${tpl.judgeCount} 题，每题 $js 分）');
    }
    if (tpl.subjectiveCount > 0) {
      sections.add('四、解答题（共 ${tpl.subjectiveCount} 题，每题 $ss 分）');
    }
    final totalQ = tpl.totalCount;
    final allowRichContent = enableRichContent || enableListening;
    final richTarget = richContentTargetCount(totalQ);
    final minRichTarget = max(1, (totalQ * 0.20).ceil());
    final maxRichTarget = max(minRichTarget, (totalQ * 0.30).floor());
    final effectiveListeningTarget = listeningCount > 0
        ? listeningCount.clamp(minRichTarget, maxRichTarget)
        : richTarget;

    // 根据开关动态构建 rich_content 字段说明
    final richFieldBlock = allowRichContent
        ? '''  "rich_content": []'''
        : '';
    final richDocBlock = allowRichContent
        ? '''
【rich_content 字段说明（启用）】
当题目涉及图形/公式/音频时，**必须**返回 rich_content 数组，每个元素形如 {"type": "...", "data": {...}}。
支持的类型：

1. 数学公式（含 LaTeX）
{"type":"math","data":{"content":"求根公式 \$\$x=\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}\$\$"}}

2. 函数图像
{"type":"math","data":{"content":"[graph: f(x)=x^2-4*x+3, x=-1..5, y=-2..10]"}}

3. 统计图
{"type":"chart","data":{"chart_type":"bar","data":"A:30,B:50,C:20","title":"分布"}}

4. 物理示意图（仅物理题）
{"type":"physics","data":{"diagram_type":"forces","params":"angle:30,mass:5,friction:0.3"}}

5. 化学结构（仅化学题）
{"type":"chemistry","data":{"diagram_type":"molecule","params":"formula:H2O"}}

6. SVG 图形
{"type":"svg","data":{"svg":"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><circle cx='50' cy='50' r='40' fill='#4CAF50'/></svg>"}}

7. 英语听力
{"type":"listening","data":{"audio_text":"Hello, welcome to our English class."}}'''
        : '''
【rich_content 字段说明（已禁用）】
本次为纯文字题目模式，**不要返回 rich_content 字段**或留空数组 []，避免拖长输出导致 JSON 截断。''';

    final richRequireBlock = allowRichContent
        ? '''10. **rich_content 启用**：当题目涉及以下情况时**必须**返回 rich_content：
    - 数学公式（含分式、根号、上下标、求和、积分等）→ type:"math"，content 用 \$\$...\$\$
    - 函数图像（一次/二次/三角/指数等）→ type:"math"，content 用 [graph: f(x)=...]
    - 统计图（柱状/折线/饼图）→ type:"chart"
    - 物理受力/电路/光路等示意图 → type:"physics"
    - 化学分子结构/反应方程 → type:"chemistry"${enableListening ? '''
    - 英语听力原文 → type:"listening"（仅英语学科使用，audio_text 必填）''' : ''}
   普通纯文字题目可留空数组 []。'''
        : '10. 本次为纯文字题目模式，不要返回 rich_content 字段或留空数组 []。';
    final chartPaperNote = enableRichContent
        ? '\n12. **图表题配额（强制）**：全卷 $totalQ 题中必须恰好有 $richTarget 道题包含 type:"chart" 的 rich_content（约 25%，保持在 20%-30%）。data.data 必须使用“标签:数值,标签:数值”格式，至少 2 组，并与题干完全一致。其余题目不得返回 chart。'
        : '\n12. 本次不开启图表题，不要返回 chart 类型。';
    final listeningPaperNote = enableListening
        ? '\n13. **听力题配额（强制）**：全卷 $totalQ 题中必须恰好有 $effectiveListeningTarget 道题包含 type:"listening" 的 rich_content（保持在 20%-30%）。audio_text 为完整可朗读段落（30-80 词），各题不得重复；若图表同时开启，两类不要放在同一道题中。'
        : '\n13. 本次不生成听力题（音频开关已关闭）。';
    // v2.7.1 按章节/知识点出题
    final chapterNote = chapterRange.trim().isNotEmpty
        ? '\n13. **章节范围**：所有题目必须围绕【${chapterRange.trim()}】范围出题。题目内容、知识点、情境都应贴近该章节。'
        : '';
    final kpNote = knowledgePointSpec.trim().isNotEmpty
        ? '\n14. **各题型知识点要求**：\n${knowledgePointSpec.trim()}\n请严格按照上述知识点分配出题，每个题型的题目必须落在指定知识点范围内。'
        : '';

    final prompt = '''
请基于下面学习资料，生成一份完整的$subject 试卷$totalLine。
适用对象：$gradeLevel。
试卷页数：约 $pageCount 面（共约 $totalQ 题）。

【重要】必须生成完整的 $totalQ 道题，不得省略或减少题量，否则试卷页数会不足。

【试卷结构】严格按以下大题顺序：
${sections.join('\n')}

【输出格式】严格只返回 JSON 数组，不要 Markdown、不要解释、不要代码块标记、不要换行省略。每个元素：
{
  "section": "一、单项选择题",
  "indexInSection": 1,
  "question_type": "choice | fill | true_false | subjective",
  "question": "题干",
  "options": ["A. 选项", "B. 选项", "C. 选项", "D. 选项"],
  "answer": "A 或 填空答案 或 正确/错误 或 主观题参考答案",
  "explanation": "详细解析（200字内）",
  "knowledge_point": "本题考查的知识点（5-12字，如：一元二次方程）",
$richFieldBlock
}
$richDocBlock

【硬性要求】
1. section 字段必须使用"一、单项选择题"/"二、填空题"/"三、判断题"/"四、解答题"中的对应值。
2. 选择题必须有 4 个选项（A/B/C/D），options 形如 ["A. xxx","B. xxx","C. xxx","D. xxx"]，答案为单个字母（如 "A"）。
3. 判断题 options 用 ["正确","错误"]，答案为"正确"或"错误"。
4. 填空题和主观题 options 必须是空数组 []。
5. 题目难度从基础到综合递增。
6. 题干要严谨、规范，符合$gradeLevel 学业水平。
7. 不要在题干中输出图片占位符、不要出现"如图所示"等无法用文字表达的描述；如有需要图形展示，请使用 rich_content 字段返回对应的图形描述。
8. 输出必须是合法 JSON，不要省略号，不要"..."。
9. knowledge_point 必填，简短描述本题考查的知识点（5-12 字）。
$richRequireBlock
11. 数学、物理、化学、英语听力、统计图等学科题目应优先使用 rich_content 体现图形信息，避免在题干中使用"如图"等无法表达的描述。
$chartPaperNote
$listeningPaperNote
$chapterNote
$kpNote

【内容审核红线（绝对禁止，违反则立即终止）】
- 禁止涉政：不得出现任何破坏国家稳定安宁、恶意涉政的内容。
- 禁止黄赌毒：不得出现色情、赌博、毒品相关内容。
- 禁止暴力血腥：不得出现暴力、血腥、残忍描写。
- 禁止色情：不得出现任何性暗示、露骨描写。
- 生物医学等学科：涉及人体器官、解剖等内容时，必须避免血腥、暴力、色情化描写。
- 若学习资料本身包含上述违禁内容，请输出空数组 [] 并在 explanation 中注明"内容涉及违禁题材"。
- 题材务必健康、积极、符合社会主义核心价值观。

【学习资料】
$materialText
''';
    // 题/页比降到约 5（避免大模型输出超长导致 JSON 截断）
    // v2.6.3：上限从 8000 提到 12000，给 rich_content 输出留足空间
    final estTokens = (totalQ * 300).clamp(4500, 12000);
    final content = await _chat(
      config,
      [
        {
          'role': 'system',
          'content':
              '你是严谨的中文试卷出题专家，熟悉国内小学/初中/高中/成年人各类考试（期末、期中、中考、高考、周测、小测、考研、考编等）的试卷格式。只输出可解析的 JSON 数组，不输出任何其他内容。',
        },
        {'role': 'user', 'content': prompt},
      ],
      maxTokens: estTokens,
    );
    final jsonText = _extractJson(content);
    List<dynamic> list;
    try {
      final decoded = jsonDecode(jsonText);
      list = decoded is List
          ? decoded
          : decoded['questions'] as List? ?? [];
    } catch (_) {
      // 容错：尝试修复被截断的 JSON
      list = _repairJsonArray(jsonText);
    }
    final paperQuestions = list
        .map((item) {
          if (item is! Map) return null;
          final map = Map<String, dynamic>.from(item);
          final q = AiQuestion.fromJson(map);
          if (q.question.trim().isEmpty) return null;
          return PaperQuestion(
            section: map['section'] as String? ?? '',
            indexInSection: (map['indexInSection'] as num?)?.toInt() ?? 0,
            question: q,
            knowledgePoint: (map['knowledge_point'] as String?)?.trim() ?? '',
          );
        })
        .whereType<PaperQuestion>()
        .toList();
    // 试卷听力题兜底：英语资料开启听力但模型返回不足时，补齐到20%-30%。
    final actualTotal = paperQuestions.length;
    final actualMinTarget = actualTotal == 0
        ? 0
        : max(1, (actualTotal * 0.20).ceil());
    final actualMaxTarget = actualTotal == 0
        ? 0
        : max(actualMinTarget, (actualTotal * 0.30).floor());
    final actualListeningTarget = actualTotal == 0
        ? 0
        : (listeningCount > 0
            ? listeningCount.clamp(actualMinTarget, actualMaxTarget)
            : richContentTargetCount(actualTotal));
    if (enableListening &&
        paperQuestions.isNotEmpty &&
        subject.contains('英语')) {
      final target = actualListeningTarget;
      final existingListening = paperQuestions.where((p) =>
          p.question.richContent
              .any((rc) => (rc['type'] ?? '') == 'listening')).length;
      if (existingListening < target) {
        // v2.7.5: 放宽正则——15-300字符，至少4个连续单词的英文片段
        // 注意：用双引号 raw string，字符类里去掉 " 避免冲突
        final englishMatches =
            RegExp(r"[A-Za-z][A-Za-z\s,.!?\-';:()]{14,300}").allMatches(materialText);
        var englishSegments = englishMatches
            .map((m) => m.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' '))
            .where((s) => s.split(RegExp(r'\s+')).length >= 4)
            .toList();
        // v2.7.5: 若资料里英文片段不够，从题目题干中再提取一次
        if (englishSegments.length < target) {
          for (final p in paperQuestions) {
            final qMatches =
                RegExp(r"[A-Za-z][A-Za-z\s,.!?\-';:()]{14,300}").allMatches(p.question.question);
            for (final m in qMatches) {
              final seg = m.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' ');
              if (seg.split(RegExp(r'\s+')).length >= 4 &&
                  !englishSegments.contains(seg)) {
                englishSegments.add(seg);
              }
            }
          }
        }
        if (englishSegments.isNotEmpty) {
          final need = (target - existingListening).clamp(0, paperQuestions.length);
          var segIdx = 0;
          var applied = 0;
          for (var i = 0; i < paperQuestions.length && applied < need; i++) {
            final p = paperQuestions[i];
            if (p.question.richContent.any((rc) => (rc['type'] ?? '') == 'listening')) continue;
            final audioText = englishSegments[segIdx % englishSegments.length];
            segIdx++;
            final newRich = <Map<String, dynamic>>[
              ...p.question.richContent,
              {
                'type': 'listening',
                'data': {'audio_text': audioText, 'voice': 'en-US'},
              },
            ];
            final newQ = AiQuestion(
              type: p.question.type,
              question: p.question.question,
              options: p.question.options,
              answer: p.question.answer,
              explanation: p.question.explanation,
              richContent: newRich,
            );
            paperQuestions[i] = PaperQuestion(
              section: p.section,
              indexInSection: p.indexInSection,
              question: newQ,
              knowledgePoint: p.knowledgePoint,
            );
            applied++;
            debugPrint('[RichContent] 试卷听力题兜底：第 ${i + 1} 题追加 listening 块（${audioText.split(RegExp(r'\s+')).length} 词）');
          }
        }
      }
    }
    final actualRichTarget = richContentTargetCount(paperQuestions.length);
    _capPaperRichContentType(
      paperQuestions,
      type: 'chart',
      target: enableRichContent ? actualRichTarget : 0,
    );
    _capPaperRichContentType(
      paperQuestions,
      type: 'listening',
      target: enableListening ? actualListeningTarget : 0,
    );
    return paperQuestions;
  }

  /// 尝试从被截断的 JSON 文本中提取完整元素
  static List<dynamic> _repairJsonArray(String text) {
    final t = text.trim();
    final start = t.indexOf('[');
    if (start < 0) return const [];
    // 找最后一个完整对象结尾 "}"
    var i = t.length - 1;
    while (i > start && t[i] != '}') {
      i--;
    }
    if (i <= start) return const [];
    final sub = t.substring(start, i + 1) + ']';
    try {
      final decoded = jsonDecode(sub);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const [];
  }

  static Future<String> _chat(
    ApiConfig config,
    List<Map<String, String>> messages, {
    int maxTokens = 1800,
  }) async {
    final base = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');
    final response = await http
        .post(
          uri,
          headers: _headersFor(config),
          body: jsonEncode({
            'model': config.model,
            'messages': messages,
            'temperature': 0.2,
            'max_tokens': maxTokens,
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API 请求失败：${response.statusCode} ${response.body}');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) throw Exception('API 没有返回 choices');
    final message = choices.first['message'] as Map?;
    return (message?['content'] ?? choices.first['text'] ?? '').toString();
  }

  static Map<String, String> _headersFor(ApiConfig config) {
    final base = config.baseUrl.toLowerCase();
    if (config.provider == 'mimo' || base.contains('xiaomimimo.com')) {
      return {'Content-Type': 'application/json', 'api-key': config.apiKey};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey}',
    };
  }

  static String _extractJson(String text) {
    var t = text.trim();
    t = t.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    t = t.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    t = t.replaceAll(RegExp(r'\s*```$'), '');
    final start = t.indexOf('[');
    final end = t.lastIndexOf(']');
    if (start >= 0 && end > start) return t.substring(start, end + 1);
    return t;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: kInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FlowStepHeader extends StatelessWidget {
  const _FlowStepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: kMuted,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: kBlue),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kBlue,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: kInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: kMuted, height: 1.5)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kLine),
      ),
      child: Column(
        children: [
          Icon(icon, color: kMuted, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: Color(0xFF92400E), height: 1.55),
          ),
        ],
      ),
    );
  }
}

String _dateText(DateTime date) =>
    '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _fileTypeLabel(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return 'PDF';
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'Word';
  if (lower.endsWith('.md')) return 'MD';
  if (lower.endsWith('.csv')) return 'CSV';
  if (lower.endsWith('.json')) return 'JSON';
  return 'TXT';
}

String _durationText(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _letter(int index) => String.fromCharCode(65 + index);

String _normalizeType(String type) {
  final t = type.trim();
  if (t == 'multi' || t == 'multiple' || t == '多选题') return 'multi_choice';
  if (t == 'judge' || t == 'truefalse' || t == '判断题') return 'true_false';
  if (t == 'blank' || t == '填空题') return 'fill';
  if (t == 'short_answer' || t == 'essay' || t == '主观题') return 'subjective';
  return t == 'choice' || t == '单选题' ? 'choice' : t;
}

String _typeLabel(String type) {
  switch (type) {
    case 'multi_choice':
      return '多选题';
    case 'true_false':
      return '判断题';
    case 'fill':
      return '填空题';
    case 'subjective':
      return '主观题';
    default:
      return '单选题';
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'multi_choice':
      return Icons.checklist_rounded;
    case 'true_false':
      return Icons.fact_check_outlined;
    case 'fill':
      return Icons.edit_rounded;
    case 'subjective':
      return Icons.short_text_rounded;
    default:
      return Icons.format_list_bulleted_rounded;
  }
}

String _answerString(dynamic answer) {
  if (answer is List) {
    return answer.map((item) => _answerString(item)).join(',');
  }
  final text = answer.toString().trim();
  final match = RegExp(r'^[A-Da-d]').firstMatch(text);
  if (match != null) return match.group(0)!.toUpperCase();
  if (text.contains('正确')) return '正确';
  if (text.contains('错误')) return '错误';
  return text;
}

Set<String> _answerSet(dynamic answer) {
  if (answer is List) {
    return answer.map(_answerString).where((item) => item.isNotEmpty).toSet();
  }
  return answer
      .toString()
      .split(RegExp(r'[,，、\s]+'))
      .map(_answerString)
      .where((item) => item.isNotEmpty)
      .toSet();
}

// ===== 通用动效组件（活力提升）=====

/// 按压缩放反馈：包装任意可点击卡片/按钮，按下时缩到 0.96，松开回弹，附带触觉反馈。
class _BouncyTap extends StatefulWidget {
  const _BouncyTap({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<_BouncyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tapDown(TapDownDetails _) {
    if (widget.enabled) _controller.forward();
  }

  void _tapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _tapCancel() {
    _controller.reverse();
  }

  void _tap() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _tapDown,
      onTapUp: _tapUp,
      onTapCancel: _tapCancel,
      onTap: _tap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// 错落淡入上移：首次构建时从下方 6% 处淡入。
class _StaggeredAppear extends StatefulWidget {
  const _StaggeredAppear({
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_StaggeredAppear> createState() => _StaggeredAppearState();
}

class _StaggeredAppearState extends State<_StaggeredAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.8, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _delayTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// 数字滚动小动画：值变化时旧值向上滑出、新值从下方滑入。
class _AnimatedValue extends StatelessWidget {
  const _AnimatedValue({
    required this.value,
    required this.style,
  });

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        value,
        key: ValueKey(value),
        style: style,
      ),
    );
  }
}

/// 等级头衔：把生硬的 Lv.N 变成有意义的称呼。
String _levelTitle(int level) {
  if (level >= 30) return '题海宗师';
  if (level >= 20) return '资深学霸';
  if (level >= 15) return '勤学达人';
  if (level >= 10) return '稳步进阶';
  if (level >= 5) return '初露锋芒';
  return '萌新出发';
}

/// 升级全屏覆盖动画：1.7s 后自动关闭，也可点击跳过。
class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({
    super.key,
    required this.newLevel,
    required this.title,
  });

  final int newLevel;
  final String title;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _ringScale;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textOffset;
  late final Animation<double> _ringRotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _glowScale = Tween(begin: 0.0, end: 1.6).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _glowOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );
    _ringScale = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.1, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.55, curve: Curves.easeOut),
      ),
    );
    _textOffset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.75, curve: Curves.easeOut),
      ),
    );
    _ringRotation = Tween(begin: 0.0, end: pi * 2).animate(_ctrl);
    _ctrl.forward();
    Future<void>.delayed(const Duration(milliseconds: 1750), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // 光晕扩散
                  Opacity(
                    opacity: _glowOpacity.value * (1 - _ctrl.value * 0.7),
                    child: Transform.scale(
                      scale: _glowScale.value,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFBBF24).withValues(alpha: 0.85),
                              const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 旋转金环
                  Transform.rotate(
                    angle: _ringRotation.value,
                    child: Transform.scale(
                      scale: _ringScale.value,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFBBF24),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFFBBF24).withValues(alpha: 0.6),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 文字
                  Opacity(
                    opacity: _textOpacity.value,
                    child: SlideTransition(
                      position: _textOffset,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'LEVEL UP',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Lv.${widget.newLevel}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 76,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFBBF24),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                        '点击任意处继续',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ===== 全局问号飘动背景 =====

class _QuestionParticle {
  const _QuestionParticle({
    required this.x,
    required this.size,
    required this.speed,
    required this.startOffset,
    required this.opacity,
    required this.swayAmplitude,
    required this.swaySpeed,
    required this.rotation,
  });

  final double x; // 0-1 相对 x 位置
  final double size; // 字号
  final double speed; // 上升速度（0-1/秒）
  final double startOffset; // 初始 y 偏移 0-1
  final double opacity; // 透明度
  final double swayAmplitude; // 左右摆动幅度 px
  final double swaySpeed; // 摆动频率
  final double rotation; // 旋转角度
}

class _FloatingQuestionsBackground extends StatefulWidget {
  const _FloatingQuestionsBackground();

  @override
  State<_FloatingQuestionsBackground> createState() =>
      _FloatingQuestionsBackgroundState();
}

class _FloatingQuestionsBackgroundState
    extends State<_FloatingQuestionsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_QuestionParticle> _particles;
  final Random _rng = Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _particles = List.generate(26, _makeParticle);
  }

  _QuestionParticle _makeParticle(int i) {
    return _QuestionParticle(
      x: _rng.nextDouble(),
      size: 14.0 + _rng.nextDouble() * 36,
      speed: 0.2 + _rng.nextDouble() * 0.4,
      startOffset: _rng.nextDouble(),
      opacity: 0.04 + _rng.nextDouble() * 0.09,
      swayAmplitude: 30 + _rng.nextDouble() * 60,
      swaySpeed: 0.8 + _rng.nextDouble() * 2.0,
      rotation: (_rng.nextDouble() - 0.5) * 0.8,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _QuestionsPainter(
              particles: _particles,
              progress: _controller.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _QuestionsPainter extends CustomPainter {
  _QuestionsPainter({required this.particles, required this.progress});

  final List<_QuestionParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (final p in particles) {
      // y 从底部往上移动，循环
      double rawY = (p.startOffset - progress * p.speed) % 1.0;
      if (rawY < 0) rawY += 1.0;
      final y = rawY * size.height;
      // x 加上左右摆动
      final sway =
          sin(progress * p.swaySpeed * 2 * pi + p.startOffset * 10) *
              p.swayAmplitude;
      final x = p.x * size.width + sway;

      // 在屏幕上方/下方淡入淡出
      final fadeY = rawY;
      double edgeFade = 1.0;
      if (fadeY < 0.08) {
        edgeFade = fadeY / 0.08;
      } else if (fadeY > 0.92) {
        edgeFade = (1.0 - fadeY) / 0.08;
      }
      final alpha = p.opacity * edgeFade;
      if (alpha < 0.005) continue;

      final span = TextSpan(
        text: '?',
        style: TextStyle(
          color: const Color(0xFF2563EB).withValues(alpha: alpha),
          fontSize: p.size,
          fontWeight: FontWeight.w900,
        ),
      );
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _QuestionsPainter old) => true;
}

/// 启动加载页：问号流动背景 + 转圈加载 + “正在加载中”文字
/// v2.7.1 重新设计的开屏动画：渐变背景 + Logo 缩放淡入 + 标题滑入 + 打字机副标题 + 进度条
class _SplashLoadingView extends StatefulWidget {
  const _SplashLoadingView();

  @override
  State<_SplashLoadingView> createState() => _SplashLoadingViewState();
}

class _SplashLoadingViewState extends State<_SplashLoadingView>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;

  // 打字机副标题
  final String _subFull = '你的智能学习训练台';
  int _subShown = 0;
  Timer? _typeTimer;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn),
    );
    _logoCtrl.forward().then((_) {
      if (mounted) _textCtrl.forward();
    });
    // 打字机
    _typeTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_subShown < _subFull.length) {
        setState(() => _subShown++);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 渐变背景
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFFFFFFF),
                  Color(0xFFF0FDF4),
                ],
              ),
            ),
          ),
        ),
        // 浮动问题粒子
        const Positioned.fill(
          child: _FloatingQuestionsBackground(),
        ),
        // 主体内容
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo 缩放淡入 - v2.7.3: 使用 APP LOGO 替代通用图标
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.32),
                          blurRadius: 28,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/app_logo.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, __) => Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // 标题滑入
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: Text(
                    'AI 题库',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                        ).createShader(
                          Rect.fromLTWH(0, 0, 220, 40),
                        ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 打字机副标题
              Text(
                _subFull.substring(0, _subShown),
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 28),
              // 进度条
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: null,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF3B82F6),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // 加载提示
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kLine),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: Color(0xFF3B82F6)),
                    SizedBox(width: 6),
                    Text(
                      '正在加载中…',
                      style: TextStyle(
                        color: kInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===== 答题评判全屏动画（老师打勾打叉）=====

class JudgeOverlay extends StatefulWidget {
  const JudgeOverlay({super.key, required this.correct});

  final bool correct;

  @override
  State<JudgeOverlay> createState() => _JudgeOverlayState();
}

class _JudgeOverlayState extends State<JudgeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _strokeProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _strokeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.2, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 950), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.correct;
    final color = correct ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Material(
      color: Colors.black.withValues(alpha: 0.35 * _opacity.value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: _opacity.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 光晕
                    Transform.scale(
                      scale: _scale.value * 1.4,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    // 主图标（手绘风打勾/打叉）
                    Transform.scale(
                      scale: _scale.value,
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: CustomPaint(
                          painter: _JudgePainter(
                            progress: _strokeProgress.value,
                            color: color,
                            correct: correct,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _JudgePainter extends CustomPainter {
  _JudgePainter({
    required this.progress,
    required this.color,
    required this.correct,
  });

  final double progress;
  final Color color;
  final bool correct;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    if (correct) {
      // 打勾：左下 → 中下 → 右上
      final p1 = Offset(cx - 50, cy + 5);
      final p2 = Offset(cx - 15, cy + 40);
      final p3 = Offset(cx + 55, cy - 35);

      if (progress < 0.45) {
        // 第一笔：p1 → p2
        final t = (progress / 0.45).clamp(0.0, 1.0);
        canvas.drawLine(p1, Offset.lerp(p1, p2, t)!, paint);
      } else {
        // 第一笔画完
        canvas.drawLine(p1, p2, paint);
        // 第二笔：p2 → p3
        final t = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
        canvas.drawLine(p2, Offset.lerp(p2, p3, t)!, paint);
      }
    } else {
      // 打叉：左上 → 右下 + 右上 → 左下
      final p1 = Offset(cx - 40, cy - 40);
      final p2 = Offset(cx + 40, cy + 40);
      final p3 = Offset(cx + 40, cy - 40);
      final p4 = Offset(cx - 40, cy + 40);

      if (progress < 0.5) {
        final t = (progress / 0.5).clamp(0.0, 1.0);
        canvas.drawLine(p1, Offset.lerp(p1, p2, t)!, paint);
      } else {
        canvas.drawLine(p1, p2, paint);
        final t = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
        canvas.drawLine(p3, Offset.lerp(p3, p4, t)!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _JudgePainter old) =>
      old.progress != progress;
}


// ============================================================
// v2.8.0: RPG Widgets (appended from artifacts/_rpg_widgets.dart)
// ============================================================

// ============================================================
// v2.8.0: 闯关 RPG 系统 —— 章节地图 / 关卡介绍 / 通关结算
// ============================================================

/// 章节地图页（粒子背景 + 节点动画 + 连线流光）
class RpgMapPage extends StatefulWidget {
  const RpgMapPage({
    super.key,
    required this.material,
    required this.subject,
    required this.progress,
    required this.onStartLevel,
  });

  final StudyMaterial material;
  final String subject;
  final RpgProgress progress;
  final void Function(int chapter, int level) onStartLevel;

  @override
  State<RpgMapPage> createState() => _RpgMapPageState();
}

class _RpgMapPageState extends State<RpgMapPage>
    with TickerProviderStateMixin {
  late final AnimationController _particleCtrl;
  late final AnimationController _flowCtrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _flowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // 生成 12 个粒子
    final rng = Random();
    _particles = List.generate(12, (_) => _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 3 + rng.nextDouble() * 4,
      color: [const Color(0xFF60A5FA), const Color(0xFFA855F7), const Color(0xFF34D399), const Color(0xFFFBBF24)][rng.nextInt(4)],
      speed: 0.3 + rng.nextDouble() * 0.7,
    ));
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _flowCtrl.dispose();
    super.dispose();
  }

  List<RpgChapter> get _chapters => _rpgChaptersForSubject(widget.subject);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 粒子背景
              AnimatedBuilder(
                animation: _particleCtrl,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ParticlePainter(_particles, _particleCtrl.value),
                    size: Size.infinite,
                  );
                },
              ),
              // 主内容
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    title: const Text('闯关挑战', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, chIdx) {
                        final chapter = _chapters[chIdx];
                        return _buildChapterSection(chapter, chIdx);
                      },
                      childCount: _chapters.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
              // 底部玩家状态条
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildStatusBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFA855F7), width: 1),
                ),
                child: Text(
                  widget.subject,
                  style: const TextStyle(color: Color(0xFFC084FC), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.material.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '章节地图',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '通关解锁下一章 · Boss 关掉落徽章',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _RpgMissionChip(icon: Icons.map_rounded, label: '3 章冒险'),
              _RpgMissionChip(icon: Icons.flag_rounded, label: '每章 5 关'),
              _RpgMissionChip(icon: Icons.extension_rounded, label: '每关 5 题'),
              _RpgMissionChip(icon: Icons.local_fire_department_rounded, label: '终关 Boss'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterSection(RpgChapter chapter, int chIdx) {
    final isCurrentChapter = chIdx + 1 == widget.progress.currentChapter;
    final isLocked = chIdx + 1 > widget.progress.currentChapter;
    final clearedLevels = List.generate(5, (index) => index + 1)
        .where((level) => widget.progress.isCleared('${chIdx + 1}-$level'))
        .length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentChapter ? chapter.color.withValues(alpha: 0.5) : const Color(0xFF334155),
          width: isCurrentChapter ? 2 : 1,
        ),
        boxShadow: isCurrentChapter
            ? [
                BoxShadow(
                  color: chapter.color.withValues(alpha: 0.14),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [chapter.color, chapter.color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(chapter.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(chapter.subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: chapter.difficulty == '简单'
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : chapter.difficulty == '中等'
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            chapter.difficulty,
                            style: TextStyle(
                              color: chapter.difficulty == '简单'
                                  ? const Color(0xFF34D399)
                                  : chapter.difficulty == '中等'
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFF87171),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chapter.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: chapter.color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$clearedLevels/5',
                  style: TextStyle(
                    color: chapter.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (isLocked) const Icon(Icons.lock_rounded, color: Color(0xFF64748B), size: 22),
            ],
          ),
          const SizedBox(height: 16),
          // 关卡节点横排 + 连线
          SizedBox(
            height: 92,
            child: Stack(
              children: [
                // 连线
                ...List.generate(4, (i) {
                  if (isLocked) return const SizedBox();
                  return Positioned(
                    left: 40 + i * 60.0,
                    top: 22,
                    child: AnimatedBuilder(
                      animation: _flowCtrl,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _FlowLinePainter(_flowCtrl.value, chapter.color),
                          size: const Size(60, 4),
                        );
                      },
                    ),
                  );
                }),
                // 5 个节点
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(5, (lvIdx) {
                    final level = lvIdx + 1;
                    final isBoss = level == 5;
                    return _LevelNode(
                      chapter: chIdx + 1,
                      level: level,
                      isBoss: isBoss,
                      color: chapter.color,
                      isUnlocked: widget.progress.isUnlocked(chIdx + 1, level),
                      stars: widget.progress.stars['${chIdx + 1}-$level'] ?? 0,
                      isCurrent: isCurrentChapter && level == widget.progress.currentLevel,
                      onTap: (widget.progress.isUnlocked(chIdx + 1, level) && !isLocked)
                          ? () => widget.onStartLevel(chIdx + 1, level)
                          : null,
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                'Lv${widget.progress.totalRpgXp ~/ 100 + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('闯关者', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.progress.unlockedBadges.length}/${_kRpgBadges.length} 徽章',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // XP 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (widget.progress.totalRpgXp % 100) / 100,
                    backgroundColor: const Color(0xFF1E293B),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 徽章预览
          Row(
            children: _kRpgBadges.take(5).map((b) {
              final unlocked = widget.progress.unlockedBadges.contains(b.id);
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  b.emoji,
                  style: TextStyle(
                    fontSize: 18,
                    color: unlocked ? null : const Color(0xFF334155),
                    decoration: unlocked ? null : TextDecoration.none,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RpgMissionChip extends StatelessWidget {
  const _RpgMissionChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF93C5FD)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  const _Particle({required this.x, required this.y, required this.size, required this.color, required this.speed});
  final double x;
  final double y;
  final double size;
  final Color color;
  final double speed;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.progress);
  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dy = (p.y + progress * p.speed) % 1.0;
      final opacity = (0.3 + 0.4 * (0.5 - (dy - 0.5).abs())).clamp(0.0, 0.7);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x * size.width, dy * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

class _FlowLinePainter extends CustomPainter {
  _FlowLinePainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // 虚线流动
    final dashWidth = 6.0;
    final dashSpace = 4.0;
    var dx = -((progress * (dashWidth + dashSpace)) % (dashWidth + dashSpace));
    while (dx < size.width) {
      canvas.drawLine(Offset(dx, size.height / 2), Offset(dx + dashWidth, size.height / 2), paint);
      dx += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _FlowLinePainter old) => old.progress != progress;
}

/// 关卡节点
class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.chapter,
    required this.level,
    required this.isBoss,
    required this.color,
    required this.isUnlocked,
    required this.stars,
    required this.isCurrent,
    required this.onTap,
  });

  final int chapter;
  final int level;
  final bool isBoss;
  final Color color;
  final bool isUnlocked;
  final int stars;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _BouncyTap(
      onTap: onTap ?? () {},
      enabled: onTap != null,
      child: SizedBox(
        width: 50,
        child: Column(
          children: [
            // 节点圆/菱形
            _buildShape(),
            const SizedBox(height: 3),
            Text(
              isBoss ? 'BOSS' : '第$level关',
              style: TextStyle(
                color: isUnlocked ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            // 星级
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(
                    Icons.star_rounded,
                    size: 10,
                    color: i < stars ? const Color(0xFFFBBF24) : const Color(0xFF334155),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShape() {
    if (!isUnlocked) {
      // 锁定状态
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: isBoss ? null : BorderRadius.circular(20),
          shape: isBoss ? BoxShape.rectangle : BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, color: Color(0xFF64748B), size: 18),
      );
    }
    // 解锁状态
    if (isBoss) {
      // Boss：菱形
      return _BossNode(
        color: color,
        isCurrent: isCurrent,
        isCleared: stars > 0,
      );
    }
    return _NormalNode(
      color: color,
      level: level,
      isCurrent: isCurrent,
      isCleared: stars > 0,
    );
  }
}

class _NormalNode extends StatefulWidget {
  const _NormalNode({required this.color, required this.level, required this.isCurrent, required this.isCleared});
  final Color color;
  final int level;
  final bool isCurrent;
  final bool isCleared;

  @override
  State<_NormalNode> createState() => _NormalNodeState();
}

class _NormalNodeState extends State<_NormalNode>
    with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 当前节点：脉冲扩散圈
          if (widget.isCurrent)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final t = _pulseCtrl.value;
                return Transform.scale(
                  scale: 1 + t * 0.8,
                  child: Opacity(
                    opacity: (1 - t) * 0.6,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                );
              },
            ),
          // 已通关：金色旋转光环
          if (widget.isCleared && !widget.isCurrent)
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _glowCtrl.value * 6.28,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4), width: 2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                );
              },
            ),
          // 主体节点
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (context, child) {
              final glowOpacity = widget.isCleared ? 0.6 + 0.4 * _glowCtrl.value : 0.0;
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [widget.color, widget.color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: widget.isCleared
                      ? [BoxShadow(color: widget.color.withValues(alpha: glowOpacity), blurRadius: 16, spreadRadius: 2)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${widget.level}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BossNode extends StatefulWidget {
  const _BossNode({required this.color, required this.isCurrent, required this.isCleared});
  final Color color;
  final bool isCurrent;
  final bool isCleared;

  @override
  State<_BossNode> createState() => _BossNodeState();
}

class _BossNodeState extends State<_BossNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = 1 + 0.12 * _ctrl.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 44,
            height: 44,
            transform: Matrix4.identity()..rotateZ(3.14159 / 4),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.isCleared ? const Color(0xFFEF4444) : const Color(0xFF7F1D1D),
                  widget.isCleared ? const Color(0xFFDC2626) : const Color(0xFF991B1B),
                ],
              ),
              border: Border.all(
                color: widget.isCleared ? const Color(0xFFFBBF24) : const Color(0xFFEF4444),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isCleared ? const Color(0xFFEF4444) : const Color(0xFF7F1D1D))
                      .withValues(alpha: 0.5 + 0.4 * _ctrl.value),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.flag_rounded, color: Colors.white, size: 20),
            ),
          ),
        );
      },
    );
  }
}

/// 关卡介绍弹窗
class RpgLevelIntroDialog extends StatelessWidget {
  const RpgLevelIntroDialog({
    super.key,
    required this.chapter,
    required this.level,
    required this.subject,
    required this.progress,
  });

  final int chapter;
  final int level;
  final String subject;
  final RpgProgress progress;

  @override
  Widget build(BuildContext context) {
    final chapters = _rpgChaptersForSubject(subject);
    final ch = chapters.length >= chapter ? chapters[chapter - 1] : null;
    final isBoss = level == 5;
    final diff = level <= 2 ? '简单' : level <= 4 ? '中等' : '困难';
    final diffColor = diff == '简单' ? const Color(0xFF34D399) : diff == '中等' ? const Color(0xFFFBBF24) : const Color(0xFFF87171);
    final levelKey = '$chapter-$level';
    final oldStars = progress.stars[levelKey] ?? 0;

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isBoss
                  ? [const Color(0xFF7F1D1D), const Color(0xFF0F172A)]
                  : [ch?.color ?? const Color(0xFF1D4ED8), const Color(0xFF0F172A)],
            ),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 关卡编号
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isBoss ? 'BOSS 关' : '关卡 $chapter-$level',
                          style: TextStyle(
                            color: isBoss ? const Color(0xFFFBBF24) : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 大图标
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isBoss
                                ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                                : [ch?.color ?? const Color(0xFF3B82F6), (ch?.color ?? const Color(0xFF1D4ED8)).withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(isBoss ? 24 : 28),
                          boxShadow: [
                            BoxShadow(
                              color: (isBoss ? const Color(0xFFEF4444) : ch?.color ?? const Color(0xFF3B82F6)).withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isBoss ? Icons.flag_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isBoss ? '综合大题挑战' : (ch?.title ?? '第$chapter章'),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isBoss ? '4 个进阶挑战 + 1 个综合 Boss' : '5 个互动挑战',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 28),
                      // 信息卡片
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            _infoRow('难度', diff, diffColor),
                            const SizedBox(height: 8),
                            _infoRow('玩法', '5 种互动题随机组合', Colors.white70),
                            const SizedBox(height: 8),
                            _infoRow('奖励', isBoss ? '100 RPG XP' : '30-50 RPG XP', const Color(0xFF34D399)),
                            const SizedBox(height: 8),
                            _infoRow('历史', oldStars > 0 ? '$oldStars 星' : '未通关', oldStars > 0 ? const Color(0xFFFBBF24) : Colors.white54),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 三星条件
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('三星条件', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            _starCond('全部答对'),
                            _starCond('用时 ≤ 2 分钟'),
                            _starCond('不跳过任何题'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // 开始按钮
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(true),
                            icon: const Icon(Icons.bolt_rounded),
                            label: Text(isBoss ? '挑战 Boss' : '开始挑战'),
                            style: FilledButton.styleFrom(
                              backgroundColor: isBoss ? const Color(0xFFEF4444) : (ch?.color ?? const Color(0xFF3B82F6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _starCond(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.star_rounded, size: 12, color: const Color(0xFFFBBF24).withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

/// 通关结算动画（三星 + XP + 徽章解锁）
class RpgLevelCompleteOverlay extends StatefulWidget {
  const RpgLevelCompleteOverlay({
    super.key,
    required this.result,
    this.onAction,
  });

  final RpgLevelResult result;
  final ValueChanged<RpgCompletionAction>? onAction;

  @override
  State<RpgLevelCompleteOverlay> createState() => _RpgLevelCompleteOverlayState();
}

class _RpgLevelCompleteOverlayState extends State<RpgLevelCompleteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _starCtrl;
  late final AnimationController _xpCtrl;
  late final AnimationController _badgeCtrl;
  late final AnimationController _introCtrl; // v2.9.1: 混合通关动画
  late final Animation<int> _xpAnim;
  // v2.9.1: 动画类型 — chest(宝箱) / fireworks(烟花) / levelup(角色升级)
  late final String _animType;
  bool _actionTaken = false;

  void _finish(RpgCompletionAction action) {
    if (_actionTaken) return;
    _actionTaken = true;
    HapticFeedback.selectionClick();
    final callback = widget.onAction;
    if (callback != null) {
      callback(action);
      return;
    }
    Navigator.of(context).pop(action);
  }

  @override
  void initState() {
    super.initState();
    _starCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _xpCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _badgeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _introCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _xpAnim = IntTween(begin: 0, end: widget.result.earnedXp).animate(
      CurvedAnimation(parent: _xpCtrl, curve: Curves.easeOut),
    );
    // v2.9.1: 确定动画类型
    final r = widget.result;
    if (r.allCleared) {
      _animType = 'levelup';
    } else if (r.level == 5) {
      _animType = 'fireworks';
    } else {
      _animType = 'chest';
    }
    _introCtrl.forward();
    _starCtrl.forward();
    Future.delayed(const Duration(milliseconds: 600), () { if (mounted) _xpCtrl.forward(); });
    if (widget.result.newBadges.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1500), () { if (mounted) _badgeCtrl.forward(); });
    }
  }

  @override
  void dispose() {
    _starCtrl.dispose();
    _xpCtrl.dispose();
    _badgeCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  // v2.9.1: 混合通关动画
  Widget _buildIntroAnimation() {
    final r = widget.result;
    if (r.stars == 0) {
      // 失败：不显示庆祝动画
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _introCtrl,
      builder: (_, __) {
        final t = _introCtrl.value;
        switch (_animType) {
          case 'chest':
            return _buildChestAnimation(t);
          case 'fireworks':
            return _buildFireworksAnimation(t);
          case 'levelup':
            return _buildLevelUpAnimation(t);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // 宝箱开启动画（普通关）
  Widget _buildChestAnimation(double t) {
    // 阶段1(0-0.4): 宝箱从下方滑入+缩放；阶段2(0.4-0.7): 盖子打开；阶段3(0.7-1.0): 金光迸射
    final slideIn = (t < 0.4) ? Curves.easeOut.transform(t / 0.4) : 1.0;
    final lidProgress = ((t - 0.4) / 0.3).clamp(0.0, 1.0);
    final lidOpen = Curves.easeOut.transform(lidProgress);
    final glow = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 光芒
          if (glow > 0)
            Transform.scale(
              scale: 1 + glow * 1.5,
              child: Opacity(
                opacity: glow,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withValues(alpha: 0.4),
                    boxShadow: [
                      BoxShadow(color: Colors.amber.withValues(alpha: glow * 0.8), blurRadius: 30),
                    ],
                  ),
                ),
              ),
            ),
          // 宝箱
          Transform.translate(
            offset: Offset(0, (1 - slideIn) * 60),
            child: Transform.scale(
              scale: slideIn,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 箱体
                  Container(
                    width: 70,
                    height: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFF92400E),
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                      border: Border.all(color: const Color(0xFFB45309), width: 2),
                    ),
                  ),
                  // 箱盖
                  Transform.translate(
                    offset: Offset(0, -22 + lidOpen * -25),
                    child: Transform.rotate(
                      angle: -lidOpen * 0.8,
                      alignment: const Alignment(-0.8, 1),
                      child: Container(
                        width: 70,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB45309),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD97706), width: 2),
                        ),
                      ),
                    ),
                  ),
                  // 金光粒子
                  if (glow > 0)
                    ...List.generate(6, (i) {
                      final angle = (i / 6) * pi * 2;
                      return Transform.translate(
                        offset: Offset(cos(angle) * glow * 50, sin(angle) * glow * 50 - 10),
                        child: Opacity(
                          opacity: glow,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 烟花庆典动画（Boss关）
  Widget _buildFireworksAnimation(double t) {
    return SizedBox(
      width: 160,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(5, (i) {
            final delay = i * 0.15;
            final localT = (t - delay).clamp(0.0, 1.0);
            if (localT <= 0) return const SizedBox.shrink();
            final expand = Curves.easeOut.transform(localT);
            final fade = 1.0 - localT;
            final colors = [Colors.amber, Colors.red, Colors.purple, Colors.green, Colors.blue];
            final cx = (i % 3 - 1) * 50.0;
            final cy = (i ~/ 3 - 0.5) * 40.0;
            return Transform.translate(
              offset: Offset(cx, cy),
              child: Opacity(
                opacity: fade,
                child: Transform.scale(
                  scale: expand,
                  child: Stack(
                    children: List.generate(12, (j) {
                      final angle = (j / 12) * pi * 2;
                      return Transform.translate(
                        offset: Offset(cos(angle) * 35, sin(angle) * 35),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors[i],
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: colors[i], blurRadius: 6)],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            );
          }),
          // 中心闪光
          if (t < 0.3)
            Opacity(
              opacity: 1 - (t / 0.3),
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 角色升级动画（里程碑 - 全部通关）
  Widget _buildLevelUpAnimation(double t) {
    // 阶段1(0-0.5): 角色发光放大；阶段2(0.5-1.0): 等级条增长+光柱
    final grow = (t < 0.5) ? Curves.elasticOut.transform(t / 0.5) : 1.0;
    final beam = (t > 0.5) ? (t - 0.5) / 0.5 : 0.0;
    return SizedBox(
      width: 120,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 光柱
          if (beam > 0)
            Positioned(
              top: 0,
              child: Opacity(
                opacity: beam * 0.6,
                child: Container(
                  width: 4,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.amber.withValues(alpha: 0), Colors.amber, Colors.amber.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          // 光环
          Transform.scale(
            scale: grow * 1.3,
            child: Opacity(
              opacity: grow,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 3),
                  boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: grow * 0.5), blurRadius: 25)],
                ),
              ),
            ),
          ),
          // 角色（用图标代替）
          Transform.scale(
            scale: grow,
            child: const Icon(Icons.person_rounded, size: 56, color: Colors.amber),
          ),
          // 等级标记
          if (beam > 0.3)
            Positioned(
              top: 5,
              child: Opacity(
                opacity: (beam - 0.3) / 0.7,
                child: Transform.scale(
                  scale: 1 + ((beam - 0.3) / 0.7) * 0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'LV UP!',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              colors: [const Color(0xFF1E3A8A).withValues(alpha: 0.4), Colors.transparent],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // v2.9.1: 混合通关动画（宝箱/烟花/角色升级）
                _buildIntroAnimation(),
                const SizedBox(height: 12),
                // 标题
                Text(
                  r.stars > 0 ? '通关！' : '挑战失败',
                  style: TextStyle(
                    color: r.stars > 0 ? Colors.white : const Color(0xFFEF4444),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${r.chapter}-${r.level} ${r.stars > 0 ? '已通关' : '再接再厉'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 28),
                // 三星
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: AnimatedStar(
                        controller: _starCtrl,
                        delay: i * 0.3,
                        earned: i < r.stars,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                // XP 计数
                AnimatedBuilder(
                  animation: _xpCtrl,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flash_on_rounded, color: Color(0xFF34D399), size: 22),
                        const SizedBox(width: 6),
                        Text(
                          '+${_xpAnim.value} XP',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                // 新徽章解锁
                if (r.newBadges.isNotEmpty)
                  AnimatedBuilder(
                    animation: _badgeCtrl,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _badgeCtrl.value,
                        child: Opacity(
                          opacity: _badgeCtrl.value,
                          child: Column(
                            children: r.newBadges.map((b) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [b.color.withValues(alpha: 0.3), b.color.withValues(alpha: 0.1)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: b.color.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(b.emoji, style: const TextStyle(fontSize: 32)),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b.name, style: TextStyle(color: b.color, fontSize: 14, fontWeight: FontWeight.w800)),
                                        Text(b.desc, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 32),
                // 按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _actionTaken
                              ? null
                              : () => _finish(RpgCompletionAction.backToMap),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('返回地图'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _actionTaken
                              ? null
                              : () => _finish(RpgCompletionAction.next),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            r.stars == 0
                                ? '重新挑战'
                                : (r.chapterCleared ? '下一章' : '下一关'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单颗星星动画（旋转 + 下落 + 光晕）
class AnimatedStar extends StatelessWidget {
  const AnimatedStar({
    super.key,
    required this.controller,
    required this.delay,
    required this.earned,
  });

  final AnimationController controller;
  final double delay;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    // 起始时间 = delay * 0.6s（与 _starCtrl 总时长 1.8s 配合）
    final start = delay * 0.6;
    final duration = 0.4;
    final t = (controller.value - start).clamp(0.0, duration) / duration;
    // 0→1：从上方落下，旋转，放大弹性
    final scale = earned ? 0.5 + Curves.elasticOut.transform(t) * 0.5 : 1.0;
    final rotate = earned ? (1 - t) * 3.14 : 0.0;
    final opacity = earned ? t.clamp(0.0, 1.0) : 0.3;

    return Transform.translate(
      offset: Offset(0, earned ? (1 - t) * -80 : 0),
      child: Transform.rotate(
        angle: rotate,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Icon(
              earned ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 56,
              color: earned ? const Color(0xFFFBBF24) : const Color(0xFF475569),
              shadows: earned
                  ? const [
                      Shadow(color: Color(0xFFFBBF24), blurRadius: 16),
                      Shadow(color: Color(0xFFF59E0B), blurRadius: 8),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}


// ===== v2.9.0: RPG 游戏化加载页 =====

class RpgLoadingView extends StatefulWidget {
  const RpgLoadingView({super.key, required this.subject});
  final String subject;

  @override
  State<RpgLoadingView> createState() => _RpgLoadingViewState();
}

class _RpgLoadingViewState extends State<RpgLoadingView>
    with TickerProviderStateMixin {
  late final AnimationController _rotateCtrl;
  late final AnimationController _pulseCtrl;
  int _tipIndex = 0;
  Timer? _tipTimer;

  static const _tips = [
    '魔法卷轴正在展开...',
    '正在召唤知识精灵...',
    '关卡迷宫正在生成...',
    'Boss 正在整理挑战...',
    '知识宝藏正在封印...',
    '勇士装备加载中...',
  ];

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _tipTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (mounted) setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IconData subjectIcon;
    switch (widget.subject) {
      case '数学': subjectIcon = Icons.calculate_rounded; break;
      case '语文': subjectIcon = Icons.menu_book_rounded; break;
      case '英语': subjectIcon = Icons.translate_rounded; break;
      case '物理': subjectIcon = Icons.bolt_rounded; break;
      case '化学': subjectIcon = Icons.science_rounded; break;
      default: subjectIcon = Icons.school_rounded;
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF6366F1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 旋转的学科图标 + 光晕
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, _) {
                    return Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF60A5FA).withValues(alpha: 0.4 + _pulseCtrl.value * 0.3),
                            blurRadius: 30 + _pulseCtrl.value * 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: RotationTransition(
                          turns: _rotateCtrl,
                          child: Icon(subjectIcon, size: 60, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                // 进度环
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                // 趣味文案
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _tips[_tipIndex],
                    key: ValueKey(_tipIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.subject} · 闯关挑战',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== v2.9.0: MiniGamePage 容器 =====

typedef MiniGameCallback = void Function({
  required bool correct,
  WrongItem? wrong,
  String? questionText,
  String? userAnswer,
  String? correctAnswer,
});

class MiniGamePage extends StatefulWidget {
  const MiniGamePage({
    super.key,
    required this.session,
    required this.onExit,
    required this.onComplete,
  });

  final MiniGameSession session;
  final VoidCallback onExit;
  final ValueChanged<MiniGameLevelResult> onComplete;

  @override
  State<MiniGamePage> createState() => _MiniGamePageState();
}

class _MiniGamePageState extends State<MiniGamePage>
    with TickerProviderStateMixin {
  int _currentGameIndex = 0;
  int _lives = 0;
  int _correct = 0;
  final List<WrongItem> _wrongs = [];
  late final DateTime _startTime;
  late final AnimationController _progressCtrl;
  bool _levelFinished = false;

  int get _total => widget.session.games.length;

  @override
  void initState() {
    super.initState();
    _lives = widget.session.lives;
    _startTime = widget.session.startTime;
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  void _onGameComplete({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) {
    if (!mounted || _levelFinished) return;
    setState(() {
      if (correct) {
        _correct++;
        HapticFeedback.lightImpact();
        SoundService.instance.play(SoundType.correct);
      } else {
        _lives--;
        HapticFeedback.heavyImpact();
        SoundService.instance.play(SoundType.wrong);
        if (wrong != null) _wrongs.add(wrong);
      }
    });
    // 生命值耗尽或完成所有 mini-game
    if (_lives <= 0 || _currentGameIndex >= _total - 1) {
      _finishLevel();
    } else {
      // 进入下一个 mini-game
      setState(() {
        _currentGameIndex++;
        _progressCtrl.forward(from: 0);
      });
    }
  }

  void _finishLevel() {
    if (_levelFinished) return;
    _levelFinished = true;
    final duration = DateTime.now().difference(_startTime);
    widget.onComplete(MiniGameLevelResult(
      total: _total,
      correct: _correct,
      duration: duration,
      wrongs: _wrongs,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.session.games[_currentGameIndex];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_currentGameIndex + 1}/$_total',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_currentGameIndex + 1) / _total,
                        minHeight: 8,
                        backgroundColor: kLine,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.session.isBoss ? kRed : kBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(widget.session.lives, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          i < _lives ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: i < _lives ? kRed : kLine,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            // Mini-game 类型标签
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(game.type.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    game.type.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    game.type.desc,
                    style: const TextStyle(fontSize: 11, color: kMuted),
                  ),
                ],
              ),
            ),
            // 当前 mini-game
            Expanded(
              child: _buildGame(game),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('放弃闯关？'),
                  content: const Text('进度将不会保存，确定退出吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('继续闯关'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onExit();
                      },
                      style: TextButton.styleFrom(foregroundColor: kRed),
                      child: const Text('放弃'),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Text(
              '${widget.session.subject} · 第${widget.session.chapter}章 第${widget.session.level}关${widget.session.isBoss ? ' · Boss' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGame(MiniGame game) {
    switch (game.type) {
      case MiniGameType.matching:
        return MatchingGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
      case MiniGameType.listening:
        return ListeningGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
      case MiniGameType.flashcard:
        return FlashcardGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
      case MiniGameType.reorder:
        return ReorderGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
      case MiniGameType.tapfast:
        return TapFastGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
      case MiniGameType.spell:
        return SpellGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
      case MiniGameType.fillblank:
        return FillBlankGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
      case MiniGameType.truefalse:
        return TrueFalseGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
      case MiniGameType.linkup:
        return LinkUpGameWidget(
          game: game,
          onComplete: _onGameComplete,
        );
    }
  }
}

// ===== v2.9.0: 辅助：Mini-Game 通用结果卡 =====

class MiniGameResultCard extends StatelessWidget {
  const MiniGameResultCard({
    super.key,
    required this.correct,
    required this.message,
  });
  final bool correct;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey('${correct}_$message'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: correct
              ? const Color(0xFFD1FAE5).withValues(alpha: 0.9)
              : const Color(0xFFFEE2E2).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: correct ? kGreen : kRed,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: correct ? kGreen : kRed,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: correct ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== v2.9.0: 1. 配对匹配 MatchingGameWidget =====

class MatchingGameWidget extends StatefulWidget {
  const MatchingGameWidget({
    super.key,
    required this.game,
    required this.onComplete,
  });
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<MatchingGameWidget> createState() => _MatchingGameWidgetState();
}

class _MatchingGameWidgetState extends State<MatchingGameWidget>
    with TickerProviderStateMixin {
  int? _selectedLeft;
  final Set<int> _matchedPairs = {};
  final Map<int, int> _pairMap = {}; // leftIdx -> rightIdx
  late final List<String> _lefts;
  late final List<String> _rights; // 已打乱的右侧
  late final List<int> _correctRightOrder; // 每个 leftIdx 对应的正确 rightIdx
  late final AnimationController _flashCtrl;
  int? _flashIdx;
  bool? _flashCorrect;

  @override
  void initState() {
    super.initState();
    _lefts = List.from(widget.game.options);
    final correctRights = widget.game.answer.split('^A');
    // 打乱右侧
    final indexedRights = <MapEntry<String, int>>[];
    for (var i = 0; i < correctRights.length; i++) {
      indexedRights.add(MapEntry(correctRights[i], i));
    }
    indexedRights.shuffle();
    _rights = indexedRights.map((e) => e.key).toList();
    _correctRightOrder = indexedRights.map((e) => e.value).toList();
    // 构建 leftIdx -> 正确 rightIdx（在 _rights 数组中的位置）
    // _pairMap[i] = 在 _rights 中的索引
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  void _onTapLeft(int i) {
    SoundService.instance.play(SoundType.click);
    setState(() => _selectedLeft = i);
  }

  void _onTapRight(int rightIdx) {
    if (_selectedLeft == null) return;
    final leftIdx = _selectedLeft!;
    // 检查是否配对正确：leftIdx 在正确数组中的位置 = rightIdx 对应的正确 rightIdx
    // 正确 rightIdx（在 _rights 数组中的位置） = _correctRightOrder.indexOf(leftIdx)
    final expectedRightIdx = _correctRightOrder.indexOf(leftIdx);
    final isCorrect = rightIdx == expectedRightIdx;
    SoundService.instance.play(isCorrect ? SoundType.correct : SoundType.wrong);
    if (isCorrect) {
      setState(() {
        _matchedPairs.add(leftIdx);
        _pairMap[leftIdx] = rightIdx;
        _selectedLeft = null;
        _flashIdx = rightIdx;
        _flashCorrect = true;
      });
      _flashCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _flashIdx = null);
      });
      HapticFeedback.lightImpact();
      // 检查是否全部完成
      if (_matchedPairs.length == _lefts.length) {
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onComplete(correct: true, questionText: widget.game.prompt);
        });
      }
    } else {
      setState(() {
        _flashIdx = rightIdx;
        _flashCorrect = false;
      });
      _flashCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _flashIdx = null);
      });
      HapticFeedback.heavyImpact();
      // 错误：扣血但不结束，允许重试
      // 如果想严格：可以扣血到 0 则结束
      // 这里设计为：配对错误允许重试，不直接结束
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.game.prompt,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          if (widget.game.knowledgePoint != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.game.knowledgePoint!,
                style: const TextStyle(fontSize: 11, color: kBlue),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // 左右两列配对
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左列
              Expanded(
                child: Column(
                  children: List.generate(_lefts.length, (i) {
                    final matched = _matchedPairs.contains(i);
                    final selected = _selectedLeft == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: matched
                            ? kGreen.withValues(alpha: 0.15)
                            : selected
                                ? kBlue.withValues(alpha: 0.15)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: matched ? null : () => _onTapLeft(i),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: matched
                                    ? kGreen
                                    : selected
                                        ? kBlue
                                        : kLine,
                                width: matched || selected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: matched
                                        ? kGreen
                                        : selected
                                            ? kBlue
                                            : kLine,
                                  ),
                                  child: Center(
                                    child: matched
                                        ? const Icon(Icons.check_rounded,
                                            size: 18, color: Colors.white)
                                        : Text(
                                            String.fromCharCode(65 + i),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: matched
                                                  ? Colors.white
                                                  : kInk,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _lefts[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: matched ? kMuted : kInk,
                                      decoration: matched
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              // 右列
              Expanded(
                child: Column(
                  children: List.generate(_rights.length, (i) {
                    final matched = _pairMap.containsValue(i);
                    final flash = _flashIdx == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: matched
                            ? kGreen.withValues(alpha: 0.15)
                            : flash && _flashCorrect == false
                                ? kRed.withValues(alpha: 0.15)
                            : flash && _flashCorrect == true
                                ? kGreen.withValues(alpha: 0.2)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: matched || _selectedLeft == null
                              ? null
                              : () => _onTapRight(i),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: matched
                                    ? kGreen
                                    : flash && _flashCorrect == false
                                        ? kRed
                                : kLine,
                                width: matched || flash ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: matched
                                        ? kGreen
                                        : kLine,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: matched ? Colors.white : kInk,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _rights[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: matched ? kMuted : kInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedLeft != null)
            const Center(
              child: Text(
                '↑ 已选中左侧，请点击右侧配对',
                style: TextStyle(fontSize: 12, color: kBlue),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== v2.9.0: 2. 听力选择 ListeningGameWidget =====

class ListeningGameWidget extends StatefulWidget {
  const ListeningGameWidget({
    super.key,
    required this.game,
    required this.onComplete,
  });
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<ListeningGameWidget> createState() => _ListeningGameWidgetState();
}

class _ListeningGameWidgetState extends State<ListeningGameWidget> {
  bool _playing = false;
  bool _played = false;
  String? _selected;
  bool? _answered;
  String? _audioError;

  Future<void> _playAudio() async {
    if (_playing) return;
    // v2.9.2: audioText 为空时用 prompt 兜底，确保有音频可播
    final ttsText = (widget.game.audioText?.isNotEmpty == true
            ? widget.game.audioText!
            : widget.game.prompt)
        .trim();
    if (ttsText.isEmpty) {
      setState(() => _audioError = '听力文本为空，无法播放');
      return;
    }
    setState(() {
      _playing = true;
      _audioError = null;
    });
    SoundService.instance.play(SoundType.click);
    FlutterEdgeTts? tts;
    AudioPlayer? player;
    var success = false;
    try {
      final isEnglish = RegExp(r'^[A-Za-z\s]').hasMatch(ttsText);
      final ttsVoiceName = isEnglish ? 'en-US-AriaNeural' : 'zh-CN-XiaoxiaoNeural';
      final ttsLocale = isEnglish ? 'en-US' : 'zh-CN';
      tts = FlutterEdgeTts(
        voice: ttsVoiceName,
        voiceLocale: ttsLocale,
        outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
        enableSentenceBoundary: true,
      );
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/rpg_listening_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await tts.synthesizeToFile(
        ttsText,
        audioFilePath: path,
        prosody: const EdgeTtsProsody(rate: '0.95', volume: '100'),
      );
      final audioFile = File(path);
      if (!await audioFile.exists() || await audioFile.length() == 0) {
        throw Exception('TTS 未生成有效音频文件');
      }
      player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      await player.play(DeviceFileSource(path));
      final timeoutSeconds = max(8, min(60, ttsText.length ~/ 4));
      await player.onPlayerComplete.first.timeout(
        Duration(seconds: timeoutSeconds),
      );
      success = true;
    } catch (e, stack) {
      debugPrint('[RPG Listening] 播放失败：$e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() {
          _audioError = '播放失败，请检查网络连接、系统音量或稍后重试';
        });
      }
    } finally {
      await player?.dispose();
      await tts?.close();
      if (mounted) {
        setState(() {
          _playing = false;
          if (success) _played = true;
        });
      }
    }
  }

  void _submit(String option) {
    if (_answered == true) return;
    // 提取 A/B/C/D
    final userAns = option.isNotEmpty ? option[0] : option;
    final correctAns = widget.game.answer.isNotEmpty
        ? widget.game.answer[0]
        : widget.game.answer;
    final isCorrect = userAns == correctAns;
    setState(() => _answered = true);
    if (isCorrect) {
      HapticFeedback.lightImpact();
      SoundService.instance.play(SoundType.correct);
    } else {
      HapticFeedback.heavyImpact();
      SoundService.instance.play(SoundType.wrong);
    }
    WrongItem? wrong;
    if (!isCorrect) {
      wrong = WrongItem(
        materialName: 'RPG 闯关',
        question: AiQuestion(
          type: 'choice',
          question: '听力题：${widget.game.audioText ?? ''}\n${widget.game.prompt}',
          options: widget.game.options,
          answer: widget.game.answer,
          explanation: widget.game.explanation ?? '',
        ),
        userAnswer: userAns,
        createdAt: DateTime.now(),
      );
    }
    Future.delayed(const Duration(milliseconds: 800), () {
      widget.onComplete(
        correct: isCorrect,
        wrong: wrong,
        questionText: widget.game.prompt,
        userAnswer: userAns,
        correctAnswer: correctAns,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.game.prompt,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 16),
          // 播放按钮
          Center(
            child: GestureDetector(
              onTap: _playing ? null : _playAudio,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _played ? kGreen : kBlue,
                      _played ? const Color(0xFF34D399) : const Color(0xFF60A5FA),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_played ? kGreen : kBlue).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _playing
                    ? const Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : Icon(
                        _played ? Icons.replay_rounded : Icons.volume_up_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _playing
                  ? '正在播放...'
                  : _played
                      ? '点击重播'
                      : '点击播放音频',
              style: TextStyle(
                fontSize: 13,
                color: kMuted,
              ),
            ),
          ),
          if (_audioError != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                _audioError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: kRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // 选项
          ...widget.game.options.map((opt) {
            final isSelected = _selected == opt;
            final userAns = opt.isNotEmpty ? opt[0] : '';
            final correctAns = widget.game.answer.isNotEmpty
                ? widget.game.answer[0]
                : '';
            final isCorrect = userAns == correctAns;
            final showCorrect = _answered == true && isCorrect;
            final showWrong = _answered == true && isSelected && !isCorrect;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: showCorrect
                    ? kGreen.withValues(alpha: 0.1)
                    : showWrong
                        ? kRed.withValues(alpha: 0.1)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _answered == true ? null : () {
                    setState(() => _selected = opt);
                    _submit(opt);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: showCorrect
                            ? kGreen
                            : showWrong
                                ? kRed
                                : kLine,
                        width: showCorrect || showWrong ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt,
                            style: TextStyle(
                              fontSize: 14,
                              color: kInk,
                            ),
                          ),
                        ),
                        if (showCorrect)
                          const Icon(Icons.check_circle_rounded, color: kGreen, size: 20)
                        else if (showWrong)
                          const Icon(Icons.cancel_rounded, color: kRed, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ===== v2.9.0: 3. 闪卡记忆 FlashcardGameWidget =====

class FlashcardGameWidget extends StatefulWidget {
  const FlashcardGameWidget({
    super.key,
    required this.game,
    required this.onComplete,
  });
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<FlashcardGameWidget> createState() => _FlashcardGameWidgetState();
}

class _FlashcardGameWidgetState extends State<FlashcardGameWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl;
  bool _showCard = true;
  bool _answered = false;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // 5 秒后自动隐藏
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showCard) {
        setState(() => _showCard = false);
        _flipCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _submit(String option) {
    if (_answered) return;
    final userAns = option.isNotEmpty ? option[0] : option;
    final correctAns = widget.game.answer.isNotEmpty
        ? widget.game.answer[0]
        : widget.game.answer;
    final isCorrect = userAns == correctAns;
    setState(() => _answered = true);
    if (isCorrect) {
      HapticFeedback.lightImpact();
      SoundService.instance.play(SoundType.correct);
    } else {
      HapticFeedback.heavyImpact();
      SoundService.instance.play(SoundType.wrong);
    }
    WrongItem? wrong;
    if (!isCorrect) {
      wrong = WrongItem(
        materialName: 'RPG 闯关',
        question: AiQuestion(
          type: 'choice',
          question: '${widget.game.prompt}\n闪卡内容：${widget.game.options.isNotEmpty ? widget.game.options.first : ''}',
          options: const [],
          answer: widget.game.answer,
          explanation: widget.game.explanation ?? '',
        ),
        userAnswer: userAns,
        createdAt: DateTime.now(),
      );
    }
    Future.delayed(const Duration(milliseconds: 800), () {
      widget.onComplete(
        correct: isCorrect,
        wrong: wrong,
        questionText: widget.game.prompt,
        userAnswer: userAns,
        correctAnswer: correctAns,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final flashcardContent = widget.game.options.isNotEmpty
        ? widget.game.options.first
        : '（无闪卡内容）';
    // 从 prompt 提取选项（A/B/C/D 在 prompt 里）
    final promptLines = widget.game.prompt.split('\n');
    final choices = <String>[];
    for (final line in promptLines) {
      final m = RegExp(r'^([A-D])[.、)]\s*(.+)').firstMatch(line.trim());
      if (m != null) {
        choices.add('${m.group(1)}. ${m.group(2)}');
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 闪卡区域
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() => _showCard = !_showCard);
                if (_showCard) {
                  _flipCtrl.forward();
                }
              },
              child: AnimatedBuilder(
                animation: _flipCtrl,
                builder: (context, child) {
                  final angle = _showCard ? 0.0 : pi;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..setEntry(3, 2, 0.002)
                      ..rotateY(angle * _flipCtrl.value),
                    child: child,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _showCard
                          ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                          : [const Color(0xFF10B981), const Color(0xFF34D399)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (_showCard ? const Color(0xFF6366F1) : kGreen)
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _showCard ? Icons.style_rounded : Icons.lightbulb_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      if (_showCard) ...[
                        const Text(
                          '闪卡内容',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          flashcardContent,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '5 秒后自动隐藏',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ] else ...[
                        const Text(
                          '答题时间',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(Icons.touch_app_rounded, size: 32, color: Colors.white),
                        const SizedBox(height: 8),
                        const Text(
                          '点击下方选项作答',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 问题（不含选项行）
          Text(
            promptLines.where((l) => !RegExp(r'^[A-D][.、)]').hasMatch(l.trim())).join('\n'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          const SizedBox(height: 16),
          // 选项
          ...choices.map((opt) {
            final isSelected = _selected == opt;
            final userAns = opt.isNotEmpty ? opt[0] : '';
            final correctAns = widget.game.answer.isNotEmpty
                ? widget.game.answer[0]
                : '';
            final isCorrect = userAns == correctAns;
            final showCorrect = _answered && isCorrect;
            final showWrong = _answered && isSelected && !isCorrect;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: showCorrect
                    ? kGreen.withValues(alpha: 0.1)
                    : showWrong
                        ? kRed.withValues(alpha: 0.1)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _answered ? null : () {
                    setState(() => _selected = opt);
                    _submit(opt);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: showCorrect
                            ? kGreen
                            : showWrong
                                ? kRed
                                : kLine,
                        width: showCorrect || showWrong ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt,
                            style: const TextStyle(fontSize: 14, color: kInk),
                          ),
                        ),
                        if (showCorrect)
                          const Icon(Icons.check_circle_rounded, color: kGreen, size: 20)
                        else if (showWrong)
                          const Icon(Icons.cancel_rounded, color: kRed, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ===== v2.9.0: 4. 顺序排列 ReorderGameWidget =====

class ReorderGameWidget extends StatefulWidget {
  const ReorderGameWidget({
    super.key,
    required this.game,
    required this.onComplete,
  });
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<ReorderGameWidget> createState() => _ReorderGameWidgetState();
}

class _ReorderGameWidgetState extends State<ReorderGameWidget> {
  late List<String> _items;
  late List<int> _correctOrder; // 正确顺序的索引
  final List<int> _userOrder = []; // 用户点击的顺序（在 _items 中的索引）
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.game.options);
    // widget.game.answer = "0,2,1,3" 表示 _items[0] 是第1个，_items[2] 是第2个...
    // 重新理解：answer = "0,2,1,3" 表示正确顺序是 _items[0], _items[2], _items[1], _items[3]
    _correctOrder = widget.game.answer
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
  }

  void _onTapItem(int i) {
    if (_answered) return;
    if (_userOrder.contains(i)) return;
    SoundService.instance.play(SoundType.click);
    setState(() => _userOrder.add(i));
    HapticFeedback.selectionClick();
    // 检查是否全部排列完成
    if (_userOrder.length == _items.length) {
      _submit();
    }
  }

  void _submit() {
    final isCorrect = _listEquals(_userOrder, _correctOrder);
    setState(() => _answered = true);
    if (isCorrect) {
      HapticFeedback.lightImpact();
      SoundService.instance.play(SoundType.correct);
    } else {
      HapticFeedback.heavyImpact();
      SoundService.instance.play(SoundType.wrong);
    }
    WrongItem? wrong;
    if (!isCorrect) {
      wrong = WrongItem(
        materialName: 'RPG 闯关',
        question: AiQuestion(
          type: 'fill',
          question: '${widget.game.prompt}\n选项：${_items.join(' | ')}',
          options: _items,
          answer: _correctOrder.map((i) => _items[i]).join(' → '),
          explanation: widget.game.explanation ?? '',
        ),
        userAnswer: _userOrder.map((i) => _items[i]).join(' → '),
        createdAt: DateTime.now(),
      );
    }
    Future.delayed(const Duration(milliseconds: 800), () {
      widget.onComplete(
        correct: isCorrect,
        wrong: wrong,
        questionText: widget.game.prompt,
        userAnswer: _userOrder.map((i) => _items[i]).join(' → '),
        correctAnswer: _correctOrder.map((i) => _items[i]).join(' → '),
      );
    });
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.game.prompt,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '按正确顺序点击下方步骤',
            style: TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 20),
          ...List.generate(_items.length, (i) {
            final selectedIdx = _userOrder.indexOf(i);
            final isSelected = selectedIdx >= 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isSelected
                    ? kBlue.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _answered ? null : () => _onTapItem(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? kBlue : kLine,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? kBlue : kBg,
                          ),
                          child: Center(
                            child: isSelected
                                ? Text(
                                    '${selectedIdx + 1}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kMuted,
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _items[i],
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? kMuted : kInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          if (_answered) ...[
            const SizedBox(height: 16),
            MiniGameResultCard(
              correct: _listEquals(_userOrder, _correctOrder),
              message: _listEquals(_userOrder, _correctOrder)
                  ? '排列正确！'
                  : '正确顺序：${_correctOrder.map((i) => _items[i]).join(' → ')}',
            ),
          ],
        ],
      ),
    );
  }
}

// ===== v2.9.0: 5. 限时快选 TapFastGameWidget =====

class TapFastGameWidget extends StatefulWidget {
  const TapFastGameWidget({
    super.key,
    required this.game,
    required this.onComplete,
  });
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<TapFastGameWidget> createState() => _TapFastGameWidgetState();
}

class _TapFastGameWidgetState extends State<TapFastGameWidget>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  late final List<String> _statements;
  late final List<bool> _correctFlags;
  late final AnimationController _timerCtrl;
  late final AnimationController _flashCtrl;
  bool _answered = false;
  bool? _lastCorrect;
  Timer? _gameTimer;
  int _remainingSeconds = 15;
  final List<String> _userAnswers = [];

  @override
  void initState() {
    super.initState();
    _statements = List.from(widget.game.options);
    _correctFlags = widget.game.answer
        .split(',')
        .map((s) => s.trim() == '对' || s.trim() == 'true' || s.trim() == '1')
        .toList();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..addListener(() {
        final remaining = (15 * (1 - _timerCtrl.value)).ceil();
        if (remaining != _remainingSeconds && mounted) {
          setState(() => _remainingSeconds = remaining);
        }
      });
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // 启动计时
    _timerCtrl.forward().then((_) {
      if (mounted && !_answered) _submit();
    });
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _flashCtrl.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _onAnswer(bool userSaysCorrect) {
    if (_answered || _currentIndex >= _statements.length) return;
    final actualCorrect = _correctFlags[_currentIndex];
    final isRight = userSaysCorrect == actualCorrect;
    _userAnswers.add(userSaysCorrect ? '对' : '错');
    if (isRight) {
      _correctCount++;
      HapticFeedback.lightImpact();
      SoundService.instance.play(SoundType.correct);
    } else {
      _wrongCount++;
      HapticFeedback.heavyImpact();
      SoundService.instance.play(SoundType.wrong);
    }
    setState(() {
      _lastCorrect = isRight;
      _flashCtrl.forward(from: 0);
    });
    // 进入下一题
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        _lastCorrect = null;
      });
      if (_currentIndex >= _statements.length) {
        _submit();
      }
    });
  }

  void _submit() {
    if (_answered) return;
    _answered = true;
    _timerCtrl.stop();
    final correct = _correctCount >= _statements.length * 0.6; // 60% 正确算通关
    if (correct) {
      SoundService.instance.play(SoundType.levelup);
    } else {
      SoundService.instance.play(SoundType.lose);
    }
    WrongItem? wrong;
    if (!correct) {
      wrong = WrongItem(
        materialName: 'RPG 闯关',
        question: AiQuestion(
          type: 'choice',
          question: '${widget.game.prompt}\n${_statements.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          options: const [],
          answer: _correctFlags.map((b) => b ? '对' : '错').join(','),
          explanation: widget.game.explanation ?? '',
        ),
        userAnswer: _userAnswers.join(','),
        createdAt: DateTime.now(),
      );
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onComplete(
        correct: correct,
        wrong: wrong,
        questionText: widget.game.prompt,
        userAnswer: _userAnswers.join(','),
        correctAnswer: _correctFlags.map((b) => b ? '对' : '错').join(','),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 倒计时进度条
          Row(
            children: [
              const Icon(Icons.timer_rounded, size: 18, color: kRed),
              const SizedBox(width: 6),
              Text(
                '${_remainingSeconds}s',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kRed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 1 - _timerCtrl.value,
                    minHeight: 6,
                    backgroundColor: kLine,
                    valueColor: const AlwaysStoppedAnimation<Color>(kRed),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_currentIndex/${_statements.length}',
                style: const TextStyle(fontSize: 12, color: kMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.game.prompt,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          const SizedBox(height: 24),
          // 当前陈述
          if (_currentIndex < _statements.length)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_currentIndex),
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _lastCorrect == true
                              ? kGreen.withValues(alpha: 0.1)
                              : _lastCorrect == false
                                  ? kRed.withValues(alpha: 0.1)
                                  : kBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _lastCorrect == true
                                ? kGreen
                                : _lastCorrect == false
                                    ? kRed
                                    : kLine,
                          ),
                        ),
                        child: Text(
                          _statements[_currentIndex],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 两个按钮：对/错
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: kGreen,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () => _onAnswer(true),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: const Column(
                                  children: [
                                    Icon(Icons.check_rounded, size: 36, color: Colors.white),
                                    SizedBox(height: 4),
                                    Text(
                                      '对',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Material(
                            color: kRed,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () => _onAnswer(false),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: const Column(
                                  children: [
                                    Icon(Icons.close_rounded, size: 36, color: Colors.white),
                                    SizedBox(height: 4),
                                    Text(
                                      '错',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_empty_rounded, size: 60, color: kMuted),
                    const SizedBox(height: 16),
                    Text(
                      '完成！正确 $_correctCount / 错误 $_wrongCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== v2.9.1: 6. 单词拼写 SpellGameWidget =====

class SpellGameWidget extends StatefulWidget {
  const SpellGameWidget({super.key, required this.game, required this.onComplete});
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<SpellGameWidget> createState() => _SpellGameWidgetState();
}

class _SpellGameWidgetState extends State<SpellGameWidget>
    with SingleTickerProviderStateMixin {
  late final String _target;
  late final List<String> _units;
  final List<int> _selected = [];
  late final AnimationController _shakeCtrl;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _target = widget.game.answer.trim();
    final chars = _target.split('');
    final rng = Random();
    _units = chars..shuffle(rng);
    if (_units.join() == _target && _units.length > 1) {
      final tmp = _units[0];
      _units[0] = _units[1];
      _units[1] = tmp;
    }
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onTapUnit(int idx) {
    if (_submitted || _selected.contains(idx)) return;
    setState(() => _selected.add(idx));
    HapticFeedback.selectionClick();
    SoundService.instance.play(SoundType.click);
    if (_selected.length == _units.length) {
      _check();
    }
  }

  void _onRemoveAt(int pos) {
    if (_submitted) return;
    setState(() => _selected.removeAt(pos));
    HapticFeedback.selectionClick();
  }

  void _check() {
    _submitted = true;
    final built = _selected.map((i) => _units[i]).join();
    final correct = built == _target;
    if (correct) {
      HapticFeedback.mediumImpact();
      SoundService.instance.play(SoundType.correct);
    } else {
      _shakeCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      SoundService.instance.play(SoundType.wrong);
    }
    WrongItem? wrong;
    if (!correct) {
      wrong = WrongItem(
        materialName: 'RPG 闯关',
        question: AiQuestion(
          type: 'spell',
          question: widget.game.prompt,
          options: const [],
          answer: _target,
          explanation: widget.game.explanation ?? '',
        ),
        userAnswer: built,
        createdAt: DateTime.now(),
      );
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      widget.onComplete(
        correct: correct,
        wrong: wrong,
        questionText: widget.game.prompt,
        userAnswer: built,
        correctAnswer: _target,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, size: 20, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.game.prompt,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kInk),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '拼写正确答案（${_units.length}个字/字母）',
              style: const TextStyle(fontSize: 12, color: kMuted),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _shakeCtrl,
            builder: (_, child) {
              final dx = _shakeCtrl.value > 0
                  ? (sin(_shakeCtrl.value * pi * 8) * 8 * (1 - _shakeCtrl.value))
                  : 0.0;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 8,
                children: List.generate(_units.length, (slot) {
                  final filled = slot < _selected.length;
                  final unit = filled ? _units[_selected[slot]] : '';
                  return GestureDetector(
                    onTap: filled ? () => _onRemoveAt(slot) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 48,
                      decoration: BoxDecoration(
                        color: filled ? const Color(0xFF6366F1) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: filled ? const Color(0xFF6366F1) : kLine,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unit,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: filled ? Colors.white : kLine,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: List.generate(_units.length, (idx) {
                final used = _selected.contains(idx);
                return GestureDetector(
                  onTap: used ? null : () => _onTapUnit(idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 54,
                    decoration: BoxDecoration(
                      color: used ? kLine : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: used ? kLine : const Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
                      boxShadow: used ? null : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _units[idx],
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: used ? kMuted : kInk,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          if (_selected.isNotEmpty && !_submitted)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(_selected.clear),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('重置'),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== v2.9.1: 7. 填空拼图 FillBlankGameWidget =====

class FillBlankGameWidget extends StatefulWidget {
  const FillBlankGameWidget({super.key, required this.game, required this.onComplete});
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<FillBlankGameWidget> createState() => _FillBlankGameWidgetState();
}

class _FillBlankGameWidgetState extends State<FillBlankGameWidget> {
  late final List<String> _parts;
  late final List<String> _bank;
  final List<String?> _filled = [];
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _parts = widget.game.prompt.split('___');
    final blanks = _parts.length - 1;
    for (var i = 0; i < blanks; i++) {
      _filled.add(null);
    }
    _bank = List<String>.from(widget.game.options)..shuffle(Random());
  }

  void _onTapWord(String word) {
    if (_submitted) return;
    final idx = _filled.indexOf(null);
    if (idx == -1) return;
    setState(() => _filled[idx] = word);
    HapticFeedback.selectionClick();
    SoundService.instance.play(SoundType.click);
  }

  void _onRemoveBlank(int idx) {
    if (_submitted) return;
    setState(() => _filled[idx] = null);
    HapticFeedback.selectionClick();
  }

  void _check() {
    _submitted = true;
    final correctAnswer = widget.game.answer.trim();
    final allFilled = _filled.every((w) => w != null);
    final built = _filled.join(' | ');
    final answers = correctAnswer.split('|').map((s) => s.trim()).toList();
    bool correct;
    if (_filled.length == 1) {
      correct = allFilled && _filled[0]!.trim() == correctAnswer;
    } else {
      correct = allFilled &&
          List.generate(_filled.length, (i) => _filled[i]!.trim() == (i < answers.length ? answers[i] : '')).every((b) => b);
    }
    if (correct) {
      HapticFeedback.mediumImpact();
      SoundService.instance.play(SoundType.correct);
    } else {
      HapticFeedback.heavyImpact();
      SoundService.instance.play(SoundType.wrong);
    }
    WrongItem? wrong;
    if (!correct) {
      wrong = WrongItem(
        materialName: 'RPG 闯关',
        question: AiQuestion(
          type: 'fillblank',
          question: widget.game.prompt,
          options: widget.game.options,
          answer: correctAnswer,
          explanation: widget.game.explanation ?? '',
        ),
        userAnswer: built,
        createdAt: DateTime.now(),
      );
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      widget.onComplete(
        correct: correct,
        wrong: wrong,
        questionText: widget.game.prompt,
        userAnswer: built,
        correctAnswer: correctAnswer,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 6,
                  children: List.generate(_parts.length, (i) {
                    final items = <Widget>[];
                    if (_parts[i].isNotEmpty) {
                      items.add(Text(
                        _parts[i],
                        style: const TextStyle(fontSize: 17, height: 2.0, color: kInk, fontWeight: FontWeight.w500),
                      ));
                    }
                    if (i < _filled.length) {
                      final filled = _filled[i];
                      if (filled != null) {
                        items.add(GestureDetector(
                          onTap: _submitted ? null : () => _onRemoveBlank(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              filled,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ));
                      } else {
                        items.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
                          ),
                          child: const Text(
                            '＿＿＿＿',
                            style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
                          ),
                        ));
                      }
                    }
                    return items;
                  }).expand((e) => e).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _bank.map((word) {
                final used = _filled.contains(word);
                return GestureDetector(
                  onTap: used ? null : () => _onTapWord(word),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: used ? kLine : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: used ? kLine : const Color(0xFF6366F1),
                        width: 1.5,
                      ),
                      boxShadow: used ? null : [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: used ? kMuted : const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (!_submitted)
            Center(
              child: ElevatedButton.icon(
                onPressed: _filled.any((w) => w == null) ? null : _check,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('提交', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== v2.9.1: 8. 真假快判 TrueFalseGameWidget（滑动卡片）=====

class TrueFalseGameWidget extends StatefulWidget {
  const TrueFalseGameWidget({super.key, required this.game, required this.onComplete});
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<TrueFalseGameWidget> createState() => _TrueFalseGameWidgetState();
}

class _TrueFalseGameWidgetState extends State<TrueFalseGameWidget>
    with TickerProviderStateMixin {
  late final AnimationController _cardCtrl;
  late final AnimationController _flashCtrl;
  double _dragX = 0;
  double _flyFrom = 0;
  double _flyTo = 0;
  bool? _result;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  void _answer(bool right) {
    if (_submitted) return;
    _submitted = true;
    final correctAnswer = widget.game.answer.trim();
    final isRight = correctAnswer == '对';
    final correct = right == isRight;
    _result = correct;
    setState(() {});
    _flashCtrl.forward(from: 0);
    _flyFrom = _dragX;
    _flyTo = right ? 500.0 : -500.0;
    _dragX = _flyTo;
    _cardCtrl.forward();
    if (correct) {
      HapticFeedback.mediumImpact();
      SoundService.instance.play(SoundType.correct);
    } else {
      HapticFeedback.heavyImpact();
      SoundService.instance.play(SoundType.wrong);
    }
    WrongItem? wrong;
    if (!correct) {
      wrong = WrongItem(
        materialName: 'RPG 闯关',
        question: AiQuestion(
          type: 'truefalse',
          question: widget.game.prompt,
          options: const [],
          answer: correctAnswer,
          explanation: widget.game.explanation ?? '',
        ),
        userAnswer: right ? '对' : '错',
        createdAt: DateTime.now(),
      );
    }
    Future.delayed(const Duration(milliseconds: 700), () {
      widget.onComplete(
        correct: correct,
        wrong: wrong,
        questionText: widget.game.prompt,
        userAnswer: right ? '对' : '错',
        correctAnswer: correctAnswer,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.swipe_rounded, size: 16, color: kMuted),
              SizedBox(width: 6),
              Text(
                '左滑=错 · 右滑=对 · 或点击按钮',
                style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (_submitted) return;
                  setState(() => _dragX += details.delta.dx);
                },
                onHorizontalDragEnd: (details) {
                  if (_submitted) return;
                  if (_dragX > 80) {
                    _answer(true);
                  } else if (_dragX < -80) {
                    _answer(false);
                  } else {
                    setState(() => _dragX = 0);
                  }
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([_cardCtrl]),
                  builder: (_, child) {
                    final dx = _submitted
                        ? _flyFrom + (_flyTo - _flyFrom) * Curves.easeIn.transform(_cardCtrl.value)
                        : _dragX;
                    final angle = (dx / 300).clamp(-0.5, 0.5);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: Transform.rotate(angle: angle, child: child),
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _flashCtrl,
                    builder: (_, child) {
                      final flash = _flashCtrl.value > 0 && _flashCtrl.value < 0.5;
                      final color = _result == true
                          ? const Color(0xFFD1FAE5)
                          : _result == false
                              ? const Color(0xFFFEE2E2)
                              : Colors.white;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: flash ? color : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _result == true
                                ? kGreen
                                : _result == false
                                    ? kRed
                                    : kLine,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.format_quote_rounded, size: 32, color: Color(0xFFD1D5DB)),
                            const SizedBox(height: 12),
                            Text(
                              widget.game.prompt,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: kInk,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!_submitted)
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: kRed,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _answer(false),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: const Column(
                          children: [
                            Icon(Icons.close_rounded, size: 32, color: Colors.white),
                            SizedBox(height: 4),
                            Text('错', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Material(
                    color: kGreen,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _answer(true),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: const Column(
                          children: [
                            Icon(Icons.check_rounded, size: 32, color: Colors.white),
                            SizedBox(height: 4),
                            Text('对', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ===== v2.9.1: 9. 连连看 LinkUpGameWidget（网格点击配对消除）=====

class LinkUpGameWidget extends StatefulWidget {
  const LinkUpGameWidget({super.key, required this.game, required this.onComplete});
  final MiniGame game;
  final void Function({
    required bool correct,
    WrongItem? wrong,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
  }) onComplete;

  @override
  State<LinkUpGameWidget> createState() => _LinkUpGameWidgetState();
}

class _LinkUpGameWidgetState extends State<LinkUpGameWidget>
    with TickerProviderStateMixin {
  late final List<_LinkTile> _tiles;
  int? _firstSelected;
  late final AnimationController _flashCtrl;
  late final AnimationController _popCtrl;
  int _clearedPairs = 0;
  int _totalPairs = 0;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final rights = widget.game.answer.split('^A');
    final lefts = widget.game.options;
    _totalPairs = lefts.length;
    final tiles = <_LinkTile>[];
    for (var i = 0; i < lefts.length && i < rights.length; i++) {
      tiles.add(_LinkTile(id: i, text: lefts[i], side: 0));
      tiles.add(_LinkTile(id: i, text: rights[i], side: 1));
    }
    tiles.shuffle(Random());
    _tiles = tiles;
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _popCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  void _onTapTile(int idx) {
    if (_submitted || _tiles[idx].cleared) return;
    if (_firstSelected == null) {
      setState(() => _firstSelected = idx);
      HapticFeedback.selectionClick();
      SoundService.instance.play(SoundType.click);
    } else if (_firstSelected == idx) {
      setState(() => _firstSelected = null);
    } else {
      final a = _tiles[_firstSelected!];
      final b = _tiles[idx];
      if (a.id == b.id && a.side != b.side) {
        setState(() {
          _tiles[_firstSelected!].cleared = true;
          _tiles[idx].cleared = true;
          _firstSelected = null;
          _clearedPairs++;
        });
        _popCtrl.forward(from: 0);
        HapticFeedback.mediumImpact();
        SoundService.instance.play(SoundType.star);
        if (_clearedPairs == _totalPairs) {
          _onAllCleared();
        }
      } else {
        final prev = _firstSelected!;
        setState(() => _firstSelected = null);
        HapticFeedback.heavyImpact();
        SoundService.instance.play(SoundType.wrong);
        _flashCtrl.forward(from: 0);
        setState(() {
          _tiles[prev].wrongFlash = true;
          _tiles[idx].wrongFlash = true;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _tiles[prev].wrongFlash = false;
              _tiles[idx].wrongFlash = false;
            });
          }
        });
      }
    }
  }

  void _onAllCleared() {
    _submitted = true;
    HapticFeedback.mediumImpact();
    SoundService.instance.play(SoundType.levelup);
    Future.delayed(const Duration(milliseconds: 400), () {
      widget.onComplete(
        correct: true,
        wrong: null,
        questionText: widget.game.prompt,
        userAnswer: '全部配对成功',
        correctAnswer: '全部配对',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.game.prompt,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kInk),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_clearedPairs/$_totalPairs',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '点击相关联的两块进行配对消除',
              style: TextStyle(fontSize: 12, color: kMuted),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_tiles.length, (idx) {
                  final tile = _tiles[idx];
                  final selected = _firstSelected == idx;
                  return GestureDetector(
                    onTap: tile.cleared ? null : () => _onTapTile(idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: tile.cleared
                            ? kLine.withValues(alpha: 0.3)
                            : tile.wrongFlash
                                ? kRed.withValues(alpha: 0.2)
                                : selected
                                    ? const Color(0xFF6366F1)
                                    : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tile.cleared
                              ? Colors.transparent
                              : tile.wrongFlash
                                  ? kRed
                                  : selected
                                      ? const Color(0xFF6366F1)
                                      : kLine,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: tile.cleared || selected || tile.wrongFlash
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: tile.cleared ? 0.3 : 1.0,
                        child: Text(
                          tile.text,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tile.cleared
                                ? kMuted
                                : selected
                                    ? Colors.white
                                    : kInk,
                            decoration: tile.cleared ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile {
  _LinkTile({required this.id, required this.text, required this.side});
  final int id;
  final String text;
  final int side;
  bool cleared = false;
  bool wrongFlash = false;
}
