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

  test('accepts a single generated object for later batch completion', () {
    final result = AiJsonParser.decodeObjectList(
      '{"question":"单对象题目","answer":"A"}',
    );

    expect(result, hasLength(1));
    expect(result.single['question'], '单对象题目');
  });

  test(
    'batch collector completes ten questions without returning a partial set',
    () async {
      var serial = 0;
      var requests = 0;
      final result = await AiJsonBatchCollector.collect(
        expectedCount: 10,
        maxBatchSize: 5,
        isValid: (item) => (item['question'] ?? '').toString().isNotEmpty,
        identityOf: (item) => item['question'].toString(),
        request: (requestedCount, requestNumber, collected) async {
          requests++;
          // 首批模拟长 JSON 被截断：只返回 4 个完整对象；收集器应继续补齐，
          // 而不是把 4 个（更不能把 1 个）当作 10 个交给答题页。
          final count = requestNumber == 1
              ? requestedCount - 1
              : requestedCount;
          final items = List.generate(count, (_) {
            serial++;
            return '{"question":"第$serial题","answer":"A"}';
          });
          return '[${items.join(',')}]';
        },
      );

      expect(result, hasLength(10));
      expect(result.map((item) => item['question']).toSet(), hasLength(10));
      expect(requests, 3);
    },
  );

  test(
    'batch collector rejects a partial result instead of opening practice',
    () async {
      await expectLater(
        AiJsonBatchCollector.collect(
          expectedCount: 10,
          maxBatchSize: 5,
          request: (_, _, _) async => '[{"question":"始终只有一道","answer":"A"}]',
        ),
        throwsA(
          isA<AiJsonIncompleteException>()
              .having((error) => error.expectedCount, 'expectedCount', 10)
              .having((error) => error.actualCount, 'actualCount', 1),
        ),
      );
    },
  );

  test(
    'batch collector adapts when provider returns one unique item per request',
    () async {
      var serial = 0;
      final requestedCounts = <int>[];
      final result = await AiJsonBatchCollector.collect(
        expectedCount: 10,
        maxBatchSize: 5,
        identityOf: (item) => item['question'].toString(),
        request: (requestedCount, _, _) async {
          requestedCounts.add(requestedCount);
          serial++;
          return '[{"question":"自适应第$serial题","answer":"A"}]';
        },
      );

      expect(result, hasLength(10));
      expect(requestedCounts.first, 5);
      expect(requestedCounts.skip(1), everyElement(1));
    },
  );

  test('batch progress reports only accepted real objects', () async {
    var serial = 0;
    final snapshots = <AiJsonBatchProgress>[];
    final result = await AiJsonBatchCollector.collect(
      expectedCount: 5,
      maxBatchSize: 3,
      identityOf: (item) => item['question'].toString(),
      onProgress: snapshots.add,
      request: (requestedCount, requestNumber, _) async {
        final count = requestNumber == 1 ? 2 : requestedCount;
        final items = List.generate(count, (_) {
          serial++;
          return '{"question":"真实题目$serial","answer":"A"}';
        });
        return '[${items.join(',')}]';
      },
    );

    expect(result, hasLength(5));
    expect(snapshots.map((item) => item.acceptedCount), [2, 4, 5]);
    expect(snapshots.last.expectedCount, 5);
    expect(snapshots.last.fraction, 1);
  });
}
