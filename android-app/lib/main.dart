import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

const kBlue = Color(0xFF2563EB);
const kBg = Color(0xFFF4F6FB);
const kInk = Color(0xFF0F172A);
const kMuted = Color(0xFF64748B);
const kLine = Color(0xFFE2E8F0);
const kGreen = Color(0xFF10B981);
const kRed = Color(0xFFEF4444);

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
  });

  final String type;
  final String question;
  final List<String> options;
  final dynamic answer;
  final String explanation;

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
  };

  factory AiQuestion.fromJson(Map<String, dynamic> json) {
    final type = (json['question_type'] ?? json['type'] ?? 'choice').toString();
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((item) => item.toString()).toList()
        : <String>[];
    return AiQuestion(
      type: _normalizeType(type),
      question: (json['question'] ?? json['title'] ?? '').toString(),
      options: _normalizeType(type) == 'true_false' && options.isEmpty
          ? const ['正确', '错误']
          : options,
      answer: json['answer'] ?? json['correct_answer'] ?? '',
      explanation: (json['explanation'] ?? json['analysis'] ?? '暂无解析')
          .toString(),
    );
  }
}

class PracticeRecord {
  PracticeRecord({
    required this.materialName,
    required this.total,
    required this.correct,
    required this.createdAt,
    this.xpEarned = 0,
    this.isWrongCardChallenge = false,
  });

  final String materialName;
  final int total;
  final int correct;
  final DateTime createdAt;
  final int xpEarned;
  final bool isWrongCardChallenge;

  int get wrong => max(0, total - correct);
  int get accuracy => total == 0 ? 0 : (correct / total * 100).round();

  Map<String, dynamic> toJson() => {
    'materialName': materialName,
    'total': total,
    'correct': correct,
    'createdAt': createdAt.toIso8601String(),
    'xpEarned': xpEarned,
    'isWrongCardChallenge': isWrongCardChallenge,
  };

  factory PracticeRecord.fromJson(Map<String, dynamic> json) => PracticeRecord(
    materialName: json['materialName'] as String? ?? '未知资料',
    total: json['total'] as int? ?? 0,
    correct: json['correct'] as int? ?? 0,
    xpEarned: json['xpEarned'] as int? ?? 0,
    isWrongCardChallenge: json['isWrongCardChallenge'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
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

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _materialsKey = 'materials_v1';
  static const _recordsKey = 'records_v1';
  static const _wrongsKey = 'wrongs_v1';
  static const _configKey = 'api_config_v1';
  static const _onboardingSeenKey = 'onboarding_seen_v1';
  static const _xpProfileKey = 'xp_profile_v1';

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
  ApiConfig _config = const ApiConfig();
  XpProfile _xpProfile = const XpProfile();
  StudyMaterial? _selectedMaterial;
  int _tab = 0;
  int _questionCount = 5;
  String _audience = '通用';
  bool _loading = true;
  bool _generating = false;
  bool _onboardingQueued = false;
  PracticeSession? _session;
  Timer? _boostTicker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final materials = _decodeList(
      prefs.getString(_materialsKey),
    ).map((item) => StudyMaterial.fromJson(item)).toList();
    final records = _decodeList(
      prefs.getString(_recordsKey),
    ).map((item) => PracticeRecord.fromJson(item)).toList();
    final wrongs = _decodeList(
      prefs.getString(_wrongsKey),
    ).map((item) => WrongItem.fromJson(item)).toList();
    final configJson = prefs.getString(_configKey);
    final xpJson = prefs.getString(_xpProfileKey);
    final onboardingSeen = prefs.getBool(_onboardingSeenKey) ?? false;
    setState(() {
      _materials = materials;
      _records = records;
      _wrongs = wrongs;
      _selectedMaterial = materials.isEmpty ? null : materials.first;
      _config = configJson == null
          ? const ApiConfig()
          : ApiConfig.fromJson(jsonDecode(configJson) as Map<String, dynamic>);
      _xpProfile = xpJson == null
          ? const XpProfile()
          : XpProfile.fromJson(jsonDecode(xpJson) as Map<String, dynamic>);
      _loading = false;
    });
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
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
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

  Future<void> _saveWrongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _wrongsKey,
      jsonEncode(_wrongs.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveXpProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_xpProfileKey, jsonEncode(_xpProfile.toJson()));
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
    HapticFeedback.selectionClick();
    setState(() => _tab = index);
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
    setState(() {
      _materials.removeWhere((item) => item.id == material.id);
      if (_selectedMaterial?.id == material.id) {
        _selectedMaterial = _materials.isEmpty ? null : _materials.first;
      }
    });
    await _saveMaterials();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'txt',
        'md',
        'csv',
        'json',
        'pdf',
        'docx',
        'doc',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final name = file.name;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnack('没有读取到文件内容');
      return;
    }
    try {
      _showSnack('正在解析 $name ...');
      final content = _extractMaterialText(name, bytes);
      if (content.trim().length < 10) {
        _showSnack('没有解析到足够的文字内容，请检查文件是否为扫描件或空文档');
        return;
      }
      await _addMaterial(name, content);
      _showSnack('已导入并解析：$name');
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
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
    } catch (error) {
      throw Exception('PDF 解析失败：$error');
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
      throw Exception('DOCX 解析失败：$error');
    }
  }

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
                ),
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
      setState(() => _tab = 4);
      _showSnack('请先配置大模型 API');
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

  Future<void> _startWrongCardChallenge() async {
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
        isWrongCardChallenge: true,
        xpMultiplier: _xpProfile.activeMultiplier(),
      );
    });
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
    final settlement = _settleXp(result);
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
        ),
      );
      if (!result.isWrongCardChallenge) {
        _wrongs.insertAll(0, result.wrongs);
      }
      _session = null;
      _tab = 3;
    });
    await _saveRecords();
    await _saveWrongs();
    await _saveXpProfile();
    _syncBoostTicker();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          XpResultDialog(settlement: settlement, profile: _xpProfile),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (session != null) {
      return PracticeScreen(
        session: session,
        onExit: () => setState(() => _session = null),
        onComplete: _completePractice,
      );
    }

    final pages = [
      MaterialsPage(
        materials: _materials,
        configReady: _config.ready,
        onPickFile: _pickFile,
        onPaste: _openPasteDialog,
        onDemo: _addDemoMaterial,
        onDelete: _deleteMaterial,
        onGenerate: (material) {
          setState(() {
            _selectedMaterial = material;
            _tab = 1;
          });
        },
        onOpenConfig: () => setState(() => _tab = 4),
      ),
      GeneratePage(
        materials: _materials,
        selectedMaterial: _selectedMaterial,
        selectedTypes: _selectedTypes,
        questionCount: _questionCount,
        audience: _audience,
        audiences: _audiences,
        generating: _generating,
        onMaterialChanged: (material) =>
            setState(() => _selectedMaterial = material),
        onToggleType: (type) {
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
        onCountChanged: (count) => setState(() => _questionCount = count),
        onAudienceChanged: (value) => setState(() => _audience = value),
        onGenerate: _generateQuestions,
      ),
      WrongBookPage(
        wrongs: _wrongs,
        xpProfile: _xpProfile,
        onDrawCards: _startWrongCardChallenge,
        onClear: () async {
          setState(() => _wrongs = []);
          await _saveWrongs();
        },
      ),
      StatsPage(
        records: _records,
        wrongs: _wrongs,
        xpProfile: _xpProfile,
        onCheckIn: _dailyCheckIn,
      ),
      ConfigPage(config: _config, onSave: _saveConfig),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            label: '资料',
          ),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: '出题'),
          NavigationDestination(icon: Icon(Icons.book_outlined), label: '错题'),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: '统计',
          ),
          NavigationDestination(icon: Icon(Icons.key_rounded), label: '配置'),
        ],
      ),
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

class MaterialsPage extends StatelessWidget {
  const MaterialsPage({
    super.key,
    required this.materials,
    required this.configReady,
    required this.onPickFile,
    required this.onPaste,
    required this.onDemo,
    required this.onDelete,
    required this.onGenerate,
    required this.onOpenConfig,
  });

  final List<StudyMaterial> materials;
  final bool configReady;
  final VoidCallback onPickFile;
  final VoidCallback onPaste;
  final VoidCallback onDemo;
  final ValueChanged<StudyMaterial> onDelete;
  final ValueChanged<StudyMaterial> onGenerate;
  final VoidCallback onOpenConfig;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _HeroHeader(configReady: configReady, onOpenConfig: onOpenConfig),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('导入资料文件'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPaste,
                icon: const Icon(Icons.edit_note),
                label: const Text('粘贴资料'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onDemo,
          icon: const Icon(Icons.science_outlined),
          label: const Text('没有资料？添加一份示例'),
        ),
        const SizedBox(height: 18),
        Text(
          '我的资料',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (materials.isEmpty)
          const _EmptyCard(
            icon: Icons.folder_open,
            title: '还没有学习资料',
            subtitle: '导入 PDF、DOCX 或文本资料，App 会自动解析内容。',
          )
        else
          ...materials.map(
            (material) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: kLine),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.description, color: kBlue),
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
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${material.content.length} 字 · ${_dateText(material.createdAt)}',
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      material.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kMuted, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => onGenerate(material),
                            child: const Text('生成题目'),
                          ),
                        ),
                        IconButton(
                          onPressed: () => onDelete(material),
                          icon: const Icon(Icons.delete_outline, color: kRed),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.configReady, required this.onOpenConfig});

  final bool configReady;
  final VoidCallback onOpenConfig;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF172554)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Text(
                'AI题库',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '安卓单体版 · 无登录 · 不需要外部后端',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            configReady ? 'API 已配置，可以直接用手机生成题目。' : '首次使用请先配置大模型 API Key。',
            style: const TextStyle(color: Colors.white, height: 1.5),
          ),
          if (!configReady) ...[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onOpenConfig,
              icon: const Icon(Icons.key),
              label: const Text('去配置 API'),
            ),
          ],
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
    required this.onMaterialChanged,
    required this.onToggleType,
    required this.onCountChanged,
    required this.onAudienceChanged,
    required this.onGenerate,
  });

  final List<StudyMaterial> materials;
  final StudyMaterial? selectedMaterial;
  final Set<String> selectedTypes;
  final int questionCount;
  final String audience;
  final List<String> audiences;
  final bool generating;
  final ValueChanged<StudyMaterial?> onMaterialChanged;
  final ValueChanged<String> onToggleType;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<String> onAudienceChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _PageTitle(title: '生成题目', subtitle: '选择资料、题型和数量，AI 将在手机端直接生成练习。'),
        const SizedBox(height: 16),
        if (materials.isEmpty)
          const _EmptyCard(
            icon: Icons.upload_file,
            title: '请先添加资料',
            subtitle: '回到资料页导入 PDF、DOCX 或文本资料后，再开始出题。',
          )
        else ...[
          DropdownButtonFormField<StudyMaterial>(
            initialValue: selectedMaterial,
            items: materials
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: onMaterialChanged,
            decoration: const InputDecoration(
              labelText: '学习资料',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '题型（可多选混合出题）',
            style: TextStyle(fontWeight: FontWeight.w900, color: kMuted),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.85,
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
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFEFF6FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? kBlue : kLine,
                          width: selected ? 2 : 1.4,
                        ),
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
          DropdownButtonFormField<String>(
            initialValue: audience,
            items: audiences
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value != null) onAudienceChanged(value);
            },
            decoration: const InputDecoration(
              labelText: '目标群体',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              '题目数量',
              style: TextStyle(fontWeight: FontWeight.w900, color: kMuted),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: questionCount <= 1
                    ? null
                    : () => onCountChanged(questionCount - 1),
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  '$questionCount',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
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
          const SizedBox(height: 24),
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
    this.isWrongCardChallenge = false,
    this.xpMultiplier = 1,
  });

  final String materialName;
  final List<AiQuestion> questions;
  final bool isWrongCardChallenge;
  final int xpMultiplier;
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
  });

  final String materialName;
  final int total;
  final int correct;
  final List<WrongItem> wrongs;
  final List<AiQuestion> questions;
  final List<bool> correctFlags;
  final bool isWrongCardChallenge;
  final int xpMultiplier;
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

  void _submit() {
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
        _wrongs.add(
          WrongItem(
            materialName: widget.session.materialName,
            question: question,
            userAnswer: answer,
            createdAt: DateTime.now(),
          ),
        );
      }
      _correctFlags.add(correct);
    });
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
      body: SafeArea(
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
                    Text(
                      question.question,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.55,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _ResultBox extends StatelessWidget {
  const _ResultBox({
    required this.correct,
    required this.answer,
    required this.explanation,
    required this.userAnswer,
  });

  final bool correct;
  final String answer;
  final String explanation;
  final String userAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? '回答正确' : '需要复习',
            style: TextStyle(
              color: correct ? kGreen : kRed,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text('你的答案：$userAnswer'),
          Text('参考答案：$answer'),
          const SizedBox(height: 8),
          Text('解析：$explanation', style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}

class WrongBookPage extends StatelessWidget {
  const WrongBookPage({
    super.key,
    required this.wrongs,
    required this.xpProfile,
    required this.onDrawCards,
    required this.onClear,
  });

  final List<WrongItem> wrongs;
  final XpProfile xpProfile;
  final VoidCallback onDrawCards;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(
              child: _PageTitle(title: '错题本', subtitle: '错题全部保存在手机本地。'),
            ),
            if (wrongs.isNotEmpty)
              TextButton(onPressed: onClear, child: const Text('清空')),
          ],
        ),
        const SizedBox(height: 12),
        _WrongCardEntry(
          wrongCount: wrongs.length,
          xpProfile: xpProfile,
          onTap: onDrawCards,
        ),
        const SizedBox(height: 14),
        if (wrongs.isEmpty)
          const _EmptyCard(
            icon: Icons.check_circle_outline,
            title: '暂无错题',
            subtitle: '做题后答错的题目会自动收录到这里。',
          )
        else
          ...wrongs.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: kLine),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.question.label} · ${item.materialName}',
                      style: const TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.question.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '你的答案：${item.userAnswer}',
                      style: const TextStyle(color: kRed),
                    ),
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
      ],
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
    return InkWell(
      onTap: wrongCount == 0 ? null : onTap,
      borderRadius: BorderRadius.circular(24),
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

class StatsPage extends StatelessWidget {
  const StatsPage({
    super.key,
    required this.records,
    required this.wrongs,
    required this.xpProfile,
    required this.onCheckIn,
  });

  final List<PracticeRecord> records;
  final List<WrongItem> wrongs;
  final XpProfile xpProfile;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final total = records.fold<int>(0, (sum, item) => sum + item.total);
    final correct = records.fold<int>(0, (sum, item) => sum + item.correct);
    final accuracy = total == 0 ? 0 : (correct / total * 100).round();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _PageTitle(title: '学习统计', subtitle: '所有数据都只保存在当前手机。'),
        const SizedBox(height: 16),
        _XpPanel(profile: xpProfile, onCheckIn: onCheckIn),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(label: '累计做题', value: '$total'),
            _StatCard(label: '正确题数', value: '$correct'),
            _StatCard(label: '正确率', value: '$accuracy%'),
            _StatCard(label: '错题数', value: '${wrongs.length}'),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '练习历史',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const _EmptyCard(
            icon: Icons.history,
            title: '还没有练习历史',
            subtitle: '完成一组题目后会显示在这里。',
          )
        else
          ...records.map(
            (record) => ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: kLine),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(
                record.materialName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${record.correct}/${record.total} 正确 · +${record.xpEarned} XP · ${_dateText(record.createdAt)}',
              ),
              trailing: Text(
                record.isWrongCardChallenge ? '抽卡' : '${record.accuracy}%',
                style: TextStyle(
                  color: record.isWrongCardChallenge
                      ? kBlue
                      : (record.accuracy >= 60 ? kGreen : kRed),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: kBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: kMuted, fontWeight: FontWeight.w800),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.bolt_rounded, color: kBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.${profile.level} · ${profile.totalXp} XP',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '连续打卡 ${profile.checkinStreak} 天',
                      style: const TextStyle(
                        color: kMuted,
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    if (_started) return;
    setState(() => _started = true);
    HapticFeedback.mediumImpact();
    await _controller.forward(from: 0);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _MistBackground()),
            Padding(
              padding: const EdgeInsets.all(22),
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
                            fontSize: 20,
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
                  const SizedBox(height: 24),
                  Text(
                    widget.canActivateBoost
                        ? '本轮抽取 5 道错题，全对即可开启三倍经验'
                        : '当前错题不足 5 道，先完成已有错题挑战',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final t = Curves.easeInOutCubic.transform(
                            _controller.value,
                          );
                          return SizedBox(
                            height: 310,
                            child: Stack(
                              alignment: Alignment.center,
                              children: List.generate(5, (index) {
                                final offset = (index - 2) * 46.0 * (1 - t);
                                final rotate = (index - 2) * 0.09 * (1 - t);
                                final scale = _done && index == 2 ? 1.12 : 1.0;
                                return Transform.translate(
                                  offset: Offset(offset, (index % 2) * 12.0),
                                  child: Transform.rotate(
                                    angle:
                                        rotate + sin(t * pi * 6 + index) * 0.03,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: _DrawCard(
                                        active: _done && index == 2,
                                        dimmed: _started && index != 2,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _done
                        ? Column(
                            key: const ValueKey('done'),
                            children: [
                              const Text(
                                '抽取成功',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '已抽取 ${widget.count} 道历史错题，准备开始挑战。',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: () => Navigator.pop(context, true),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('开始挑战'),
                              ),
                            ],
                          )
                        : SizedBox(
                            key: const ValueKey('ready'),
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _draw,
                              icon: const Icon(Icons.style_rounded),
                              label: const Text('开始抽卡'),
                            ),
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
  const _DrawCard({required this.active, required this.dimmed});

  final bool active;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: 116,
      height: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
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
              active ? Icons.quiz_rounded : Icons.school_rounded,
              color: active ? kBlue : Colors.white70,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              active ? '错题卡' : 'AI题库',
              style: TextStyle(
                color: active ? kInk : Colors.white70,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final title = settlement.isCheckin
        ? '打卡成功'
        : (settlement.boostActivated ? '三倍经验已开启' : '练习完成');
    final subtitle = settlement.isCheckin
        ? '连续第 ${settlement.streak} 天，获得 ${settlement.finalXp} XP。'
        : (settlement.multiplier > 1
              ? '本轮处于三倍经验，获得 ${settlement.finalXp} XP。'
              : '本轮获得 ${settlement.finalXp} XP。');
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 14),
          _XpLine(label: '基础经验', value: '${settlement.baseXp} XP'),
          _XpLine(label: '倍率', value: '×${settlement.multiplier}'),
          _XpLine(label: '最终获得', value: '${settlement.finalXp} XP'),
          const Divider(height: 24),
          Text(
            '当前等级：Lv.${profile.level} · 总经验 ${profile.totalXp} XP',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (settlement.boostActivated) ...[
            const SizedBox(height: 10),
            const Text(
              '现在去练习，接下来 10 分钟内经验值 ×3。',
              style: TextStyle(color: Color(0xFFF97316)),
            ),
          ],
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
    'zhipu': ('智谱', 'https://api.z.ai/api/paas/v4', 'glm-4.5-flash'),
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
        const _NoteCard(
          title: '不知道 API Key 在哪里获取？',
          body:
              '请打开官网 aichuti.ccwu.cc/#apikey 查看“API Key 获取与配置指南”。官网会列出 DeepSeek、Qwen、智谱、小米 MiMo、Kimi 的控制台入口和填写示例。',
        ),
        const SizedBox(height: 12),
        const _NoteCard(
          title: '本地化说明',
          body: '本 App 不提供账号系统，资料、API Key、练习记录都保存在当前手机。卸载 App 会删除这些本地数据。',
        ),
      ],
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
  }) async {
    final typeText = types.map(_typeLabel).join('、');
    final materialText = material.length > 6500
        ? material.substring(0, 6500)
        : material;
    final prompt =
        '''
请基于下面学习资料生成 $count 道题，目标群体：$audience。
题型范围：$typeText。

严格只返回 JSON，不要 Markdown，不要解释。JSON 格式如下：
[
  {
    "question_type": "choice | multi_choice | true_false | fill | subjective",
    "question": "题干",
    "options": ["A. 选项", "B. 选项"],
    "answer": "A 或 [\\"A\\",\\"C\\"] 或 正确/错误 或 填空答案",
    "explanation": "解析"
  }
]

要求：
1. 单选题必须有 4 个选项，答案为 A/B/C/D。
2. 多选题必须有 4 个选项，答案为数组。
3. 判断题 options 可为 ["正确","错误"]。
4. 填空题和主观题 options 为空数组。
5. question_type 必须使用：${types.join(',')}。

学习资料：
$materialText
''';
    final content = await _chat(config, [
      {'role': 'system', 'content': '你是严谨的中文学习题库出题助手，只输出可解析 JSON。'},
      {'role': 'user', 'content': prompt},
    ]);
    final jsonText = _extractJson(content);
    final decoded = jsonDecode(jsonText);
    final list = decoded is List
        ? decoded
        : decoded['questions'] as List? ?? [];
    return list
        .map(
          (item) => AiQuestion.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .where((q) => q.question.trim().isNotEmpty)
        .toList();
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
        .timeout(const Duration(seconds: 45));
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

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
