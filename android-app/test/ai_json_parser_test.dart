import 'package:ai_question_bank_android/core/ai/ai_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a complete fenced JSON array', () {
    final result = AiJsonParser.decodeObjectList('''
```json
[
  {"question":"第一题","answer":"A"},
  {"question":"第二题","answer":"B"}
]
```
''');

    expect(result, hasLength(2));
    expect(result.last['question'], '第二题');
  });

  test('salvages complete questions when the last object is truncated', () {
    final result = AiJsonParser.decodeObjectList('''
[
  {"question":"完整题目","options":["A","B"],"answer":"A"},
  {"question":"被截断题目","options":["A","B
''');

    expect(result, hasLength(1));
    expect(result.single['question'], '完整题目');
  });

  test('reads arrays wrapped in a root object', () {
    final result = AiJsonParser.decodeObjectList(
      '{"questions":[{"question":"根对象题目","answer":"正确"}]}',
    );

    expect(result.single['question'], '根对象题目');
  });
}
