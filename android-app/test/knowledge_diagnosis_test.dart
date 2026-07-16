import 'package:flutter_test/flutter_test.dart';

import 'package:ai_question_bank_android/features/wrong_book/knowledge_diagnosis.dart';

void main() {
  final start = DateTime(2026, 7, 1);

  KnowledgeDiagnosis diagnosis({
    required String name,
    required int total,
    required int wrong,
    required int streak,
    required int lastWrongDay,
    required int lastAttemptDay,
  }) {
    return KnowledgeDiagnosis(
      name: name,
      total: total,
      wrong: wrong,
      lastWrongAt: start.add(Duration(days: lastWrongDay)),
      lastAttemptAt: start.add(Duration(days: lastAttemptDay)),
      consecutiveCorrect: streak,
      wrongQuestions: const [],
      explanations: const [],
    );
  }

  test('aggregates attempts and keeps actionable mistake details', () {
    final diagnoses = buildKnowledgeDiagnoses([
      KnowledgeAttempt(
        knowledgePoint: '二次函数',
        isCorrect: false,
        occurredAt: start,
        question: '顶点坐标是什么？',
        explanation: '使用顶点公式。',
      ),
      KnowledgeAttempt(
        knowledgePoint: '二次函数',
        isCorrect: true,
        occurredAt: start.add(const Duration(days: 1)),
      ),
      KnowledgeAttempt(
        knowledgePoint: '二次函数',
        isCorrect: true,
        occurredAt: start.add(const Duration(days: 2)),
      ),
    ]);

    expect(diagnoses, hasLength(1));
    expect(diagnoses.single.wrong, 1);
    expect(diagnoses.single.accuracy, 67);
    expect(diagnoses.single.consecutiveCorrect, 2);
    expect(diagnoses.single.mastery, KnowledgeMastery.improving);
    expect(diagnoses.single.lastAttemptAt, start.add(const Duration(days: 2)));
    expect(diagnoses.single.wrongQuestions, ['顶点坐标是什么？']);
    expect(diagnoses.single.explanations, ['使用顶点公式。']);
  });

  test('mastery follows the centralized correct-streak rules', () {
    expect(
      diagnosis(
        name: '待巩固',
        total: 4,
        wrong: 3,
        streak: 1,
        lastWrongDay: 1,
        lastAttemptDay: 2,
      ).mastery,
      KnowledgeMastery.needsWork,
    );
    expect(
      diagnosis(
        name: '进步中',
        total: 4,
        wrong: 2,
        streak: 2,
        lastWrongDay: 1,
        lastAttemptDay: 3,
      ).mastery,
      KnowledgeMastery.improving,
    );
    expect(
      diagnosis(
        name: '已掌握',
        total: 10,
        wrong: 2,
        streak: 4,
        lastWrongDay: 1,
        lastAttemptDay: 5,
      ).mastery,
      KnowledgeMastery.mastered,
    );
  });

  test('supports all four diagnosis sort modes', () {
    final items = [
      diagnosis(
        name: 'A',
        total: 10,
        wrong: 2,
        streak: 4,
        lastWrongDay: 2,
        lastAttemptDay: 6,
      ),
      diagnosis(
        name: 'B',
        total: 5,
        wrong: 4,
        streak: 0,
        lastWrongDay: 5,
        lastAttemptDay: 5,
      ),
      diagnosis(
        name: 'C',
        total: 5,
        wrong: 2,
        streak: 2,
        lastWrongDay: 4,
        lastAttemptDay: 8,
      ),
    ];

    expect(
      sortKnowledgeDiagnoses(
        items,
        KnowledgeDiagnosisSort.weakest,
      ).map((item) => item.name),
      ['B', 'C', 'A'],
    );
    expect(
      sortKnowledgeDiagnoses(
        items,
        KnowledgeDiagnosisSort.mostWrong,
      ).map((item) => item.name),
      ['B', 'C', 'A'],
    );
    expect(
      sortKnowledgeDiagnoses(
        items,
        KnowledgeDiagnosisSort.recentWrong,
      ).map((item) => item.name),
      ['B', 'C', 'A'],
    );
    expect(
      sortKnowledgeDiagnoses(
        items,
        KnowledgeDiagnosisSort.recentPractice,
      ).map((item) => item.name),
      ['C', 'A', 'B'],
    );
  });

  test('omits knowledge points that never had a mistake', () {
    final diagnoses = buildKnowledgeDiagnoses([
      KnowledgeAttempt(
        knowledgePoint: '集合',
        isCorrect: true,
        occurredAt: start,
      ),
    ]);

    expect(diagnoses, isEmpty);
  });

  test('reinforce query supports current questions and legacy records', () {
    final current = diagnosis(
      name: 'Widgets',
      total: 1,
      wrong: 1,
      streak: 0,
      lastWrongDay: 1,
      lastAttemptDay: 1,
    );
    final currentWithQuestion = KnowledgeDiagnosis(
      name: current.name,
      total: current.total,
      wrong: current.wrong,
      lastWrongAt: current.lastWrongAt,
      lastAttemptAt: current.lastAttemptAt,
      consecutiveCorrect: current.consecutiveCorrect,
      wrongQuestions: const ['Which widget creates immutable UI?'],
      explanations: const [],
    );
    expect(
      knowledgeReinforceQuery(currentWithQuestion, 'Flutter notes.pdf'),
      'Which widget creates immutable UI?',
    );

    final legacy = KnowledgeDiagnosis(
      name: 'Flutter组件基础',
      total: 1,
      wrong: 1,
      lastWrongAt: start,
      lastAttemptAt: start,
      consecutiveCorrect: 0,
      wrongQuestions: const ['Flutter组件基础'],
      explanations: const [],
    );
    expect(knowledgeReinforceQuery(legacy, '旧资料.txt'), '旧资料.txt');
  });
}
