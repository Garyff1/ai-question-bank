import 'package:ai_question_bank_android/features/audio/listening_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listening_script 与可见问题分离并清理 Markdown', () {
    final value = ListeningQuestionData.fromJson({
      'listening_script': '**Tom** arrives at 8:30 a.m.\nPlease meet him.',
      'question': 'When does Tom arrive?',
      'answer': 'B',
    });
    expect(value.script, 'Tom arrives at 8:30 a.m. Please meet him.');
    expect(value.isValid, isTrue);
  });

  test('兼容旧 listening rich_content 数据', () {
    final value = ListeningQuestionData.fromJson({
      'rich_content': [
        {
          'type': 'listening',
          'data': {'audio_text': 'Welcome to London.', 'voice': 'en_GB'},
        },
      ],
    });
    expect(value.script, 'Welcome to London.');
    expect(value.voiceLocale, 'en-GB');
  });

  test('检测显式泄露答案的听力脚本', () {
    expect(
      ListeningQuestionData.exposesAnswer(
        script: 'The correct answer is B.',
        answer: 'B',
      ),
      isTrue,
    );
    expect(
      ListeningQuestionData.exposesAnswer(
        script: 'Tom takes the bus at eight.',
        answer: 'B',
      ),
      isFalse,
    );
  });
}
