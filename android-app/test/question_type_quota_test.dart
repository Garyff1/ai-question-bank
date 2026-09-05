import 'package:ai_question_bank_android/core/ai/question_type_quota.dart';
import 'package:ai_question_bank_android/core/ai/ai_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('even distribution keeps the requested total and type order', () {
    final plan = QuestionTypeQuotaPlan.evenlyDistributed(
      types: const ['choice', 'multi_choice', 'fill'],
      totalCount: 10,
    );

    expect(plan.targets, {'choice': 4, 'multi_choice': 3, 'fill': 3});
    expect(plan.totalCount, 10);
  });

  test('batch plan requests the largest remaining type deficits first', () {
    final plan = QuestionTypeQuotaPlan.fromTargets({
      'choice': 3,
      'multi_choice': 2,
      'fill': 1,
    });
    final accepted = <Map<String, dynamic>>[
      {'question_type': 'choice'},
      {'question_type': 'multi_choice'},
    ];

    expect(plan.nextBatchTypes(accepted, 3), [
      'choice',
      'choice',
      'multi_choice',
    ]);
    expect(
      plan.instructionForBatch(const ['choice', 'choice', 'multi_choice']),
      contains('choice 2 道'),
    );
  });

  test('quota rejects an extra type and accepts a missing type', () {
    final plan = QuestionTypeQuotaPlan.fromTargets({
      'choice': 1,
      'multi_choice': 1,
    });
    final accepted = <Map<String, dynamic>>[
      {'question_type': 'choice'},
    ];

    expect(
      plan.canAccept({'question_type': 'single_choice'}, accepted),
      isFalse,
    );
    expect(
      plan.canAccept({'question_type': 'multiple_choice'}, accepted),
      isTrue,
    );
  });

  test('section fallback and aliases normalize consistently', () {
    expect(
      QuestionTypeQuotaPlan.typeOf({'section': '二、多项选择题'}),
      'multi_choice',
    );
    expect(QuestionTypeQuotaPlan.normalizeType('judgment'), 'true_false');
    expect(QuestionTypeQuotaPlan.normalizeType('fill-blank'), 'fill');
  });

  test('matching total is not enough when type quota is missing', () {
    final plan = QuestionTypeQuotaPlan.fromTargets({'choice': 2, 'fill': 1});

    expect(
      plan.isSatisfiedByTypes(const ['choice', 'choice', 'choice']),
      isFalse,
    );
    expect(plan.missingForTypes(const ['choice', 'choice', 'choice']), {
      'fill': 1,
    });
  });

  test(
    'collector rejects over-quota objects and finishes with exact mix',
    () async {
      final plan = QuestionTypeQuotaPlan.fromTargets({'choice': 1, 'fill': 1});
      var requestNumber = 0;
      final result = await AiJsonBatchCollector.collectWithDiagnostics(
        expectedCount: 2,
        maxBatchSize: 2,
        maxRequests: 2,
        identityOf: (item) => item['question'].toString(),
        canAccept: (item, accepted) => plan.canAccept(item, accepted),
        request: (_, _, _) async {
          requestNumber++;
          if (requestNumber == 1) {
            return '[{"question_type":"choice","question":"选择1"},'
                '{"question_type":"choice","question":"选择2"}]';
          }
          return '[{"question_type":"fill","question":"填空1"}]';
        },
      );

      expect(result.items.map(QuestionTypeQuotaPlan.typeOf), [
        'choice',
        'fill',
      ]);
      expect(result.diagnostics.acceptanceRejectedCount, 1);
      expect(plan.isSatisfiedByItems(result.items), isTrue);
    },
  );
}
