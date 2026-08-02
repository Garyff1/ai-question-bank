class PaperBuilderSettings {
  const PaperBuilderSettings({
    this.paperName = '自定义试卷',
    this.totalQuestions = 20,
    this.durationMinutes = 30,
    this.totalScore = 100,
    this.questionCounts = const {
      'choice': 8,
      'multi_choice': 2,
      'true_false': 3,
      'fill': 4,
      'subjective': 3,
    },
    this.questionScores = const {
      'choice': 3,
      'multi_choice': 4,
      'true_false': 2,
      'fill': 5,
      'subjective': 10,
    },
    this.basicPercent = 40,
    this.normalPercent = 40,
    this.hardPercent = 20,
    this.generateAnswers = true,
    this.generateExplanations = true,
    this.generateKnowledgePoints = true,
    this.includeCharts = false,
    this.includeListening = false,
    this.preferWrongs = false,
    this.avoidHistoricalDuplicates = true,
    this.serviceMode = 'byok',
    this.selectedMaterialIds = const [],
  });

  final String paperName;
  final int totalQuestions;
  final int durationMinutes;
  final int totalScore;
  final Map<String, int> questionCounts;
  final Map<String, int> questionScores;
  final int basicPercent;
  final int normalPercent;
  final int hardPercent;
  final bool generateAnswers;
  final bool generateExplanations;
  final bool generateKnowledgePoints;
  final bool includeCharts;
  final bool includeListening;
  final bool preferWrongs;
  final bool avoidHistoricalDuplicates;
  final String serviceMode;
  final List<String> selectedMaterialIds;

  int get questionCountSum =>
      questionCounts.values.fold<int>(0, (sum, value) => sum + value);
  int get scoreSum => questionCounts.entries.fold<int>(
    0,
    (sum, entry) => sum + entry.value * (questionScores[entry.key] ?? 0),
  );
  int get difficultySum => basicPercent + normalPercent + hardPercent;
  bool get countsValid => questionCountSum == totalQuestions;
  bool get scoresValid => scoreSum == totalScore;
  bool get difficultyValid => difficultySum == 100;
  bool get valid => countsValid && scoresValid && difficultyValid;

  PaperBuilderSettings copyWith({
    String? paperName,
    int? totalQuestions,
    int? durationMinutes,
    int? totalScore,
    Map<String, int>? questionCounts,
    Map<String, int>? questionScores,
    int? basicPercent,
    int? normalPercent,
    int? hardPercent,
    bool? generateAnswers,
    bool? generateExplanations,
    bool? generateKnowledgePoints,
    bool? includeCharts,
    bool? includeListening,
    bool? preferWrongs,
    bool? avoidHistoricalDuplicates,
    String? serviceMode,
    List<String>? selectedMaterialIds,
  }) => PaperBuilderSettings(
    paperName: paperName ?? this.paperName,
    totalQuestions: totalQuestions ?? this.totalQuestions,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    totalScore: totalScore ?? this.totalScore,
    questionCounts: questionCounts ?? this.questionCounts,
    questionScores: questionScores ?? this.questionScores,
    basicPercent: basicPercent ?? this.basicPercent,
    normalPercent: normalPercent ?? this.normalPercent,
    hardPercent: hardPercent ?? this.hardPercent,
    generateAnswers: generateAnswers ?? this.generateAnswers,
    generateExplanations: generateExplanations ?? this.generateExplanations,
    generateKnowledgePoints:
        generateKnowledgePoints ?? this.generateKnowledgePoints,
    includeCharts: includeCharts ?? this.includeCharts,
    includeListening: includeListening ?? this.includeListening,
    preferWrongs: preferWrongs ?? this.preferWrongs,
    avoidHistoricalDuplicates:
        avoidHistoricalDuplicates ?? this.avoidHistoricalDuplicates,
    serviceMode: serviceMode ?? this.serviceMode,
    selectedMaterialIds: selectedMaterialIds ?? this.selectedMaterialIds,
  );

  PaperBuilderSettings autoFillQuestionCounts() {
    final keys = questionCounts.keys.toList();
    if (keys.isEmpty) return this;
    final current = questionCountSum;
    if (current == totalQuestions) return this;
    final result = Map<String, int>.from(questionCounts);
    if (current <= 0) {
      final each = totalQuestions ~/ keys.length;
      for (final key in keys) result[key] = each;
      for (var i = 0; i < totalQuestions % keys.length; i++) {
        result[keys[i]] = (result[keys[i]] ?? 0) + 1;
      }
    } else {
      var assigned = 0;
      for (var i = 0; i < keys.length; i++) {
        final key = keys[i];
        final value = i == keys.length - 1
            ? totalQuestions - assigned
            : ((questionCounts[key] ?? 0) * totalQuestions / current).round();
        result[key] = value.clamp(0, totalQuestions);
        assigned += result[key]!;
      }
      while (result.values.fold<int>(0, (a, b) => a + b) < totalQuestions) {
        result[keys.first] = (result[keys.first] ?? 0) + 1;
      }
      while (result.values.fold<int>(0, (a, b) => a + b) > totalQuestions) {
        final key = keys.reversed.firstWhere((k) => (result[k] ?? 0) > 0);
        result[key] = result[key]! - 1;
      }
    }
    return copyWith(questionCounts: result);
  }

  PaperBuilderSettings autoAdjustScores() {
    if (questionCountSum <= 0 || totalScore <= 0) return this;
    final scores = Map<String, int>.from(questionScores);
    for (final key in questionCounts.keys) scores[key] = 1;
    var current = questionCounts.values.fold<int>(0, (a, b) => a + b);
    final priority = [
      'subjective',
      'fill',
      'multi_choice',
      'choice',
      'true_false',
    ];
    var guard = 0;
    while (current < totalScore && guard++ < totalScore * 2) {
      var progressed = false;
      for (final key in priority) {
        final count = questionCounts[key] ?? 0;
        if (count <= 0 || current + count > totalScore) continue;
        scores[key] = (scores[key] ?? 1) + 1;
        current += count;
        progressed = true;
        if (current == totalScore) break;
      }
      if (!progressed) break;
    }
    return copyWith(questionScores: scores);
  }

  Map<String, dynamic> toJson() => {
    'paperName': paperName,
    'totalQuestions': totalQuestions,
    'durationMinutes': durationMinutes,
    'totalScore': totalScore,
    'questionCounts': questionCounts,
    'questionScores': questionScores,
    'basicPercent': basicPercent,
    'normalPercent': normalPercent,
    'hardPercent': hardPercent,
    'generateAnswers': generateAnswers,
    'generateExplanations': generateExplanations,
    'generateKnowledgePoints': generateKnowledgePoints,
    'includeCharts': includeCharts,
    'includeListening': includeListening,
    'preferWrongs': preferWrongs,
    'avoidHistoricalDuplicates': avoidHistoricalDuplicates,
    'serviceMode': serviceMode,
    'selectedMaterialIds': selectedMaterialIds,
  };

  factory PaperBuilderSettings.fromJson(Map<String, dynamic> json) {
    Map<String, int> intMap(Object? raw, Map<String, int> fallback) {
      if (raw is! Map) return fallback;
      return raw.map(
        (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
      );
    }

    return PaperBuilderSettings(
      paperName: json['paperName'] as String? ?? '自定义试卷',
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 20,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 100,
      questionCounts: intMap(
        json['questionCounts'],
        const PaperBuilderSettings().questionCounts,
      ),
      questionScores: intMap(
        json['questionScores'],
        const PaperBuilderSettings().questionScores,
      ),
      basicPercent: (json['basicPercent'] as num?)?.toInt() ?? 40,
      normalPercent: (json['normalPercent'] as num?)?.toInt() ?? 40,
      hardPercent: (json['hardPercent'] as num?)?.toInt() ?? 20,
      generateAnswers: json['generateAnswers'] as bool? ?? true,
      generateExplanations: json['generateExplanations'] as bool? ?? true,
      generateKnowledgePoints: json['generateKnowledgePoints'] as bool? ?? true,
      includeCharts: json['includeCharts'] as bool? ?? false,
      includeListening: json['includeListening'] as bool? ?? false,
      preferWrongs: json['preferWrongs'] as bool? ?? false,
      avoidHistoricalDuplicates:
          json['avoidHistoricalDuplicates'] as bool? ?? true,
      serviceMode: json['serviceMode'] as String? ?? 'byok',
      selectedMaterialIds:
          (json['selectedMaterialIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class PaperEditorQuestion {
  const PaperEditorQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.knowledgePoint,
    required this.score,
    required this.section,
    this.richContent = const [],
    this.locked = false,
    this.needsReview = false,
  });

  final String id;
  final String type;
  final String prompt;
  final List<String> options;
  final Object? answer;
  final String explanation;
  final String knowledgePoint;
  final int score;
  final String section;
  final List<Map<String, dynamic>> richContent;
  final bool locked;
  final bool needsReview;

  PaperEditorQuestion copyWith({
    String? id,
    String? type,
    String? prompt,
    List<String>? options,
    Object? answer,
    String? explanation,
    String? knowledgePoint,
    int? score,
    String? section,
    List<Map<String, dynamic>>? richContent,
    bool? locked,
    bool? needsReview,
  }) => PaperEditorQuestion(
    id: id ?? this.id,
    type: type ?? this.type,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    answer: answer ?? this.answer,
    explanation: explanation ?? this.explanation,
    knowledgePoint: knowledgePoint ?? this.knowledgePoint,
    score: score ?? this.score,
    section: section ?? this.section,
    richContent: richContent ?? this.richContent,
    locked: locked ?? this.locked,
    needsReview: needsReview ?? this.needsReview,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'prompt': prompt,
    'options': options,
    'answer': answer,
    'explanation': explanation,
    'knowledgePoint': knowledgePoint,
    'score': score,
    'section': section,
    'richContent': richContent,
    'locked': locked,
    'needsReview': needsReview,
  };

  factory PaperEditorQuestion.fromJson(Map<String, dynamic> json) =>
      PaperEditorQuestion(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'choice',
        prompt: json['prompt'] as String? ?? '',
        options:
            (json['options'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        answer: json['answer'],
        explanation: json['explanation'] as String? ?? '',
        knowledgePoint: json['knowledgePoint'] as String? ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
        section: json['section'] as String? ?? '',
        richContent:
            (json['richContent'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [],
        locked: json['locked'] as bool? ?? false,
        needsReview: json['needsReview'] as bool? ?? false,
      );
}

class PaperEditorDocument {
  const PaperEditorDocument({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.totalScore,
    required this.materialName,
    required this.questions,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final int totalScore;
  final String materialName;
  final List<PaperEditorQuestion> questions;
  final DateTime updatedAt;

  PaperEditorDocument copyWith({
    String? name,
    int? durationMinutes,
    int? totalScore,
    List<PaperEditorQuestion>? questions,
    DateTime? updatedAt,
  }) => PaperEditorDocument(
    id: id,
    name: name ?? this.name,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    totalScore: totalScore ?? this.totalScore,
    materialName: materialName,
    questions: questions ?? this.questions,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'durationMinutes': durationMinutes,
    'totalScore': totalScore,
    'materialName': materialName,
    'questions': questions.map((q) => q.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PaperEditorDocument.fromJson(
    Map<String, dynamic> json,
  ) => PaperEditorDocument(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '未命名试卷',
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
    totalScore: (json['totalScore'] as num?)?.toInt() ?? 100,
    materialName: json['materialName'] as String? ?? '',
    questions:
        (json['questions'] as List?)
            ?.whereType<Map>()
            .map(
              (e) => PaperEditorQuestion.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList() ??
        const [],
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}
