import 'package:ai_question_bank_android/features/paper_builder/models/paper_builder_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('question auto-fill reaches target without negative counts', () {
    const settings = PaperBuilderSettings(
      totalQuestions: 17,
      questionCounts: {
        'choice': 2,
        'multi_choice': 1,
        'true_false': 1,
        'fill': 1,
        'subjective': 1,
      },
    );

    final adjusted = settings.autoFillQuestionCounts();
    expect(adjusted.questionCountSum, 17);
    expect(adjusted.questionCounts.values.every((value) => value >= 0), isTrue);
  });

  test('difficulty validation and JSON round-trip preserve settings', () {
    const settings = PaperBuilderSettings(
      paperName: '期末复习卷',
      totalQuestions: 10,
      durationMinutes: 45,
      basicPercent: 30,
      normalPercent: 50,
      hardPercent: 20,
      selectedMaterialIds: ['a', 'b'],
      serviceMode: 'official',
    );

    final restored = PaperBuilderSettings.fromJson(settings.toJson());
    expect(restored.difficultyValid, isTrue);
    expect(restored.paperName, '期末复习卷');
    expect(restored.selectedMaterialIds, ['a', 'b']);
    expect(restored.serviceMode, 'official');
  });

  test('invalid count and difficulty totals are detected', () {
    const settings = PaperBuilderSettings(
      totalQuestions: 99,
      basicPercent: 30,
      normalPercent: 30,
      hardPercent: 30,
    );

    expect(settings.countsValid, isFalse);
    expect(settings.difficultyValid, isFalse);
    expect(settings.valid, isFalse);
  });
}
