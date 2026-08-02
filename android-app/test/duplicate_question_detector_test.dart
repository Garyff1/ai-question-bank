import 'package:ai_question_bank_android/features/paper_builder/duplicate_question_detector.dart';
import 'package:ai_question_bank_android/features/paper_builder/models/paper_builder_models.dart';
import 'package:flutter_test/flutter_test.dart';

PaperEditorQuestion question(String id, String prompt, List<String> options) =>
    PaperEditorQuestion(
      id: id,
      type: 'choice',
      prompt: prompt,
      options: options,
      answer: options.first,
      explanation: '',
      knowledgePoint: '',
      score: 2,
      section: '选择题',
    );

void main() {
  test('finds highly similar prompts', () {
    final matches = DuplicateQuestionDetector.detect([
      question('1', '下列关于二次函数的说法正确的是？', ['A', 'B']),
      question('2', '下列关于二次函数的说法正确的是。', ['C', 'D']),
    ]);

    expect(matches, isNotEmpty);
    expect(matches.first.reason, contains('题干'));
  });

  test('does not flag clearly different questions', () {
    final matches = DuplicateQuestionDetector.detect([
      question('1', '计算三角形面积', ['A', 'B']),
      question('2', '解释光合作用过程', ['C', 'D']),
    ]);

    expect(matches, isEmpty);
  });
}
