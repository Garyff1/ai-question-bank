import 'package:ai_question_bank_android/main.dart';
import 'package:flutter_test/flutter_test.dart';

AiQuestion _question(
  String text, {
  List<Map<String, dynamic>> rich = const [],
}) {
  return AiQuestion.fromJson({
    'question_type': 'choice',
    'question': text,
    'options': ['A. 甲', 'B. 乙', 'C. 丙', 'D. 丁'],
    'answer': 'A',
    'explanation': '解析',
    'rich_content': rich,
  });
}

WrongItem _wrong(String materialName, AiQuestion question, String answer) {
  return WrongItem(
    materialName: materialName,
    question: question,
    userAnswer: answer,
    createdAt: DateTime(2026, 7, 11),
  );
}

void main() {
  test('chart rich content prefers real data from question text', () {
    final question = _question(
      '根据柱状图数据如下：甲:10，乙:20，丙:30，判断哪项正确？',
      rich: [
        {
          'type': 'chart',
          'data': {'chart_type': 'bar', 'data': 'A:999,B:888', 'title': '旧数据'},
        },
      ],
    );

    final chart = question.richContent.firstWhere(
      (item) => item['type'] == 'chart',
    );
    expect(chart['data']['data'], '甲:10,乙:20,丙:30');
  });

  test('chart fallback parses parenthesized textbook data', () {
    final question = _question('观察折线图，数据如下：一月（12）、二月（18）、三月（25）。');

    final chart = question.richContent.firstWhere(
      (item) => item['type'] == 'chart',
    );
    expect(chart['data']['chart_type'], 'line');
    expect(chart['data']['data'], '一月:12,二月:18,三月:25');
  });

  test(
    'wrong-card reconciliation removes solved wrongs and keeps failed ones',
    () {
      final q1 = _question('第一题：基础概念判断。');
      final q2 = _question('第二题：应用题。');
      final existing = [_wrong('资料A', q1, 'B'), _wrong('资料A', q2, 'C')];
      final incoming = [_wrong('资料A', q2, 'D')];

      final merged = mergeWrongItems(
        existing,
        incoming,
        resolvedQuestions: [q1, q2],
      );

      expect(merged, hasLength(1));
      expect(merged.first.materialName, '资料A');
      expect(merged.first.question.question, q2.question);
      expect(merged.first.userAnswer, 'D');
    },
  );
}
