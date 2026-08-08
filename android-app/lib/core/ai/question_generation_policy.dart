import 'package:flutter/services.dart';

/// Shared source-grounding rules used by every AI question-generation path.
///
/// The human-readable policy ships with the app as an asset so it can be
/// reviewed independently from prompt code. A compact fallback keeps question
/// generation available if an asset is missing in an unusual test/build setup.
class QuestionGenerationPolicy {
  const QuestionGenerationPolicy._();

  static const assetPath = 'assets/prompts/question_generation_policy.md';

  static const _fallback = '''
【资料锚定出题规范】
1. 每道题都必须直接考查学习资料中的概念、原理、方法、公式、实验、案例或推论；仅凭资料即可作答。
2. 先覆盖章节主线和高频核心知识，再少量覆盖次要知识；不要把目录、页码、字数、章节数量、习题数量等文档元数据当作知识点。
3. 图表只能表达资料中的专业数据、变量关系、实验结果或与核心知识直接相关的合理情境；禁止生成“各章节习题数量/题目数量/页数/字数分布”等统计图。
4. knowledge_point 必须写明真实学科知识点；source_basis 应给出资料中的简短事实依据，不得编造资料外前提。
5. 若无法从资料找到明确依据，应改出另一道有依据的题，不能用常识或文档结构凑题。
''';

  static String? _cached;

  static Future<String> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final value = await rootBundle.loadString(assetPath);
      _cached = value.trim().isEmpty ? _fallback : value.trim();
    } catch (_) {
      _cached = _fallback;
    }
    return _cached!;
  }

  /// Rejects document-metadata questions that are syntactically valid but do
  /// not assess the subject matter itself.
  static bool isClearlyIrrelevantMetadataQuestion(Map<String, dynamic> item) {
    final text = _flatten(item).toLowerCase();
    if (text.isEmpty) return false;
    return _metadataPatterns.any((pattern) => pattern.hasMatch(text));
  }

  static String _flatten(Object? value) {
    if (value is Map) {
      return value.entries
          .where((entry) => entry.key != 'answer')
          .map((entry) => '${entry.key} ${_flatten(entry.value)}')
          .join(' ');
    }
    if (value is Iterable) return value.map(_flatten).join(' ');
    return value?.toString() ?? '';
  }

  static final List<RegExp> _metadataPatterns = [
    RegExp(r'各.{0,4}章(?:节)?.{0,4}(?:习题|题目|练习)(?:数|数量|分布|统计)'),
    RegExp(
      r'(?:每|各)章(?:节)?.{0,4}(?:有|包含|共有)?.{0,3}\d*.{0,2}(?:道|个)(?:习题|题目|练习)',
    ),
    RegExp(r'(?:习题|题目|练习)(?:数量|数目|总数)(?:分布|统计|对比|最多|最少)'),
    RegExp(r'(?:页数|字数|字符数|段落数|目录层级)(?:分布|统计|对比|最多|最少)'),
    RegExp(r'(?:本资料|本教材|本文档).{0,8}(?:共有|包含).{0,8}(?:章|页|字|题)'),
    RegExp(r'(?:chapter|section).{0,12}(?:question|exercise) count'),
    RegExp(
      r'(?:question|exercise|page|word) count.{0,12}(?:chapter|section|distribution)',
    ),
  ];
}
