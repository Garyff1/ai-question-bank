import 'package:ai_question_bank_android/core/ai/question_generation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects document-metadata chart questions', () {
    final item = <String, dynamic>{
      'question': '根据图表，哪一章的习题数量最多？',
      'answer': '第三章',
      'rich_content': [
        {
          'type': 'chart',
          'data': {
            'title': '教材各章节习题数量',
            'xLabels': ['第二章', '第三章'],
            'series': [
              {
                'name': '题目数',
                'values': [10, 15],
              },
            ],
          },
        },
      ],
    };

    expect(
      QuestionGenerationPolicy.isClearlyIrrelevantMetadataQuestion(item),
      isTrue,
    );
  });

  test('keeps subject-domain chart questions', () {
    final item = <String, dynamic>{
      'question': '负载增加时，机器人关节电机电流如何变化？',
      'answer': '随负载增加而增大',
      'knowledge_point': '关节驱动',
      'rich_content': [
        {
          'type': 'chart',
          'data': {
            'title': '负载与电机电流关系',
            'xLabels': ['轻载', '中载', '重载'],
            'series': [
              {
                'name': '电流',
                'values': [1.2, 2.0, 3.1],
              },
            ],
          },
        },
      ],
    };

    expect(
      QuestionGenerationPolicy.isClearlyIrrelevantMetadataQuestion(item),
      isFalse,
    );
  });
}
