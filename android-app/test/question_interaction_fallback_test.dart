import 'package:ai_question_bank_android/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('choice without options becomes an answerable written question', () {
    final question = AiQuestion.fromJson({
      'question_type': 'choice',
      'question': '请判断以下六条陈述是否正确，并说明理由。',
      'answer': '第1、2条正确',
    });

    expect(question.type, 'subjective');
    expect(question.options, isEmpty);
  });

  test('lettered option text is normalized into selectable choices', () {
    final question = AiQuestion.fromJson({
      'question_type': 'single_choice',
      'question': '角度是多少？',
      'options': 'A. 70°\nB. 80°\nC. 90°\nD. 100°',
      'answer': 'C',
    });

    expect(question.type, 'choice');
    expect(question.options, ['70°', '80°', '90°', '100°']);
  });

  test('sorting aliases retain draggable options', () {
    final question = AiQuestion.fromJson({
      'question_type': 'ordering',
      'question': '按过程先后排序',
      'options': ['读取资料', '提取知识', '生成题目'],
      'answer': ['读取资料', '提取知识', '生成题目'],
    });

    expect(question.type, 'sort');
    expect(question.options, hasLength(3));
  });

  test('true false questions always expose two tappable options', () {
    final question = AiQuestion.fromJson({
      'question_type': 'boolean',
      'question': 'Flutter 使用 Dart。',
      'answer': '正确',
    });

    expect(question.type, 'true_false');
    expect(question.options, ['正确', '错误']);
  });
}
