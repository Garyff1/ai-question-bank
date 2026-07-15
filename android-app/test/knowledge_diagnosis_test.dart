import 'package:flutter_test/flutter_test.dart';

import 'package:ai_question_bank_android/features/wrong_book/knowledge_diagnosis.dart';

void main() {
  test('builds actionable diagnoses and keeps the latest correct streak', () {
    final start = DateTime(2026, 7, 1);
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
    expect(diagnoses.single.consecutiveCorrect, 2);
    expect(diagnoses.single.mastery, KnowledgeMastery.improving);
    expect(diagnoses.single.wrongQuestions, ['顶点坐标是什么？']);
  });

  test('omits knowledge points that never had a mistake', () {
    final diagnoses = buildKnowledgeDiagnoses([
      KnowledgeAttempt(
        knowledgePoint: '集合',
        isCorrect: true,
        occurredAt: DateTime(2026, 7, 1),
      ),
    ]);

    expect(diagnoses, isEmpty);
  });
}
