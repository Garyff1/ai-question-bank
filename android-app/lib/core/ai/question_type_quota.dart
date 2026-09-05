/// A deterministic question-type quota used by batched AI generation.
///
/// The model is told which types to return in each batch, while the collector
/// independently rejects objects that would exceed the requested distribution.
/// This keeps the final result aligned with the user's selection instead of
/// treating a matching total count as success.
class QuestionTypeQuotaPlan {
  QuestionTypeQuotaPlan._(Map<String, int> targets)
    : targets = Map<String, int>.unmodifiable(targets);

  factory QuestionTypeQuotaPlan.fromTargets(Map<String, int> targets) {
    final normalized = <String, int>{};
    for (final entry in targets.entries) {
      final type = normalizeType(entry.key);
      final count = entry.value < 0 ? 0 : entry.value;
      if (type.isEmpty || count == 0) continue;
      normalized[type] = (normalized[type] ?? 0) + count;
    }
    return QuestionTypeQuotaPlan._(normalized);
  }

  factory QuestionTypeQuotaPlan.evenlyDistributed({
    required Iterable<String> types,
    required int totalCount,
  }) {
    final normalizedTypes = <String>[];
    for (final raw in types) {
      final type = normalizeType(raw);
      if (type.isNotEmpty && !normalizedTypes.contains(type)) {
        normalizedTypes.add(type);
      }
    }
    if (normalizedTypes.isEmpty || totalCount <= 0) {
      return QuestionTypeQuotaPlan._(const {});
    }
    final base = totalCount ~/ normalizedTypes.length;
    final remainder = totalCount % normalizedTypes.length;
    final result = <String, int>{};
    for (var index = 0; index < normalizedTypes.length; index++) {
      final count = base + (index < remainder ? 1 : 0);
      if (count > 0) result[normalizedTypes[index]] = count;
    }
    return QuestionTypeQuotaPlan._(result);
  }

  final Map<String, int> targets;

  int get totalCount => targets.values.fold(0, (sum, value) => sum + value);

  bool get isEmpty => targets.isEmpty;

  Map<String, int> countsForItems(Iterable<Map<String, dynamic>> items) {
    return countsForTypes(items.map(typeOf));
  }

  Map<String, int> countsForTypes(Iterable<String?> types) {
    final counts = <String, int>{for (final type in targets.keys) type: 0};
    for (final raw in types) {
      final type = normalizeType(raw ?? '');
      if (targets.containsKey(type)) counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> missingForItems(Iterable<Map<String, dynamic>> items) =>
      missingForCounts(countsForItems(items));

  Map<String, int> missingForTypes(Iterable<String?> types) =>
      missingForCounts(countsForTypes(types));

  Map<String, int> missingForCounts(Map<String, int> counts) {
    return <String, int>{
      for (final entry in targets.entries)
        if (entry.value - (counts[entry.key] ?? 0) > 0)
          entry.key: entry.value - (counts[entry.key] ?? 0),
    };
  }

  bool isSatisfiedByItems(Iterable<Map<String, dynamic>> items) =>
      missingForItems(items).isEmpty;

  bool isSatisfiedByTypes(Iterable<String?> types) =>
      missingForTypes(types).isEmpty;

  /// Selects an exact type mix for the next provider request.
  ///
  /// Types with the largest remaining deficit are selected first. Ties retain
  /// the insertion order supplied by the caller, making plans deterministic.
  List<String> nextBatchTypes(
    Iterable<Map<String, dynamic>> accepted,
    int requestedCount,
  ) {
    if (requestedCount <= 0 || targets.isEmpty) return const [];
    final remaining = Map<String, int>.from(missingForItems(accepted));
    final result = <String>[];
    while (result.length < requestedCount) {
      String? selected;
      var largestDeficit = 0;
      for (final type in targets.keys) {
        final deficit = remaining[type] ?? 0;
        if (deficit > largestDeficit) {
          largestDeficit = deficit;
          selected = type;
        }
      }
      if (selected == null) break;
      result.add(selected);
      remaining[selected] = largestDeficit - 1;
    }
    return result;
  }

  bool canAccept(
    Map<String, dynamic> item,
    Iterable<Map<String, dynamic>> accepted,
  ) {
    final type = typeOf(item);
    final target = targets[type];
    if (target == null || target <= 0) return false;
    final current = countsForItems(accepted)[type] ?? 0;
    return current < target;
  }

  String instructionForBatch(List<String> types) {
    if (types.isEmpty) return '';
    final counts = <String, int>{};
    for (final type in types) {
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final details = counts.entries
        .map((entry) => '${entry.key} ${entry.value} 道')
        .join('；');
    return '本批题型配额（必须严格满足）：$details。每个对象的 question_type 必须与配额一致。';
  }

  static String typeOf(Map<String, dynamic> item) {
    final direct = normalizeType(item['question_type'] ?? item['type'] ?? '');
    if (direct.isNotEmpty) return direct;
    final section = (item['section'] ?? '').toString();
    if (section.contains('多项') || section.contains('多选')) {
      return 'multi_choice';
    }
    if (section.contains('单项') || section.contains('单选')) return 'choice';
    if (section.contains('填空')) return 'fill';
    if (section.contains('判断')) return 'true_false';
    if (section.contains('解答') || section.contains('主观')) {
      return 'subjective';
    }
    return '';
  }

  static String normalizeType(Object raw) {
    final value = raw
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return switch (value) {
      'choice' || 'single_choice' || 'single' || 'mcq' => 'choice',
      'multi_choice' ||
      'multiple_choice' ||
      'multiple' ||
      'multi' ||
      'checkbox' => 'multi_choice',
      'true_false' ||
      'truefalse' ||
      'boolean' ||
      'judge' ||
      'judgement' ||
      'judgment' => 'true_false',
      'fill' || 'fill_blank' || 'fillblank' || 'blank' => 'fill',
      'subjective' ||
      'essay' ||
      'short_answer' ||
      'open_answer' ||
      'open' => 'subjective',
      'sort' || 'ordering' || 'reorder' => 'sort',
      _ => value,
    };
  }
}
