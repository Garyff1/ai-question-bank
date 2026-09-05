import 'package:ai_question_bank_android/core/ai/ai_json_parser.dart';
import 'package:ai_question_bank_android/features/paper_generation/paper_generation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('20 道试卷按 3 道小批次规划', () {
    const plan = PaperGenerationPlan(targetCount: 20);
    expect(plan.batches, [3, 3, 3, 3, 3, 3, 2]);
    expect(plan.safeRequestLimit, 9);
  });

  test('部分成功结果保留缺失数量和逐层诊断', () {
    const collection = AiJsonCollectionDiagnostics(
      expectedCount: 20,
      requestCount: 7,
      decodedCount: 19,
      invalidCount: 2,
      duplicateCount: 1,
      acceptedCount: 16,
      emptyResponseCount: 0,
      requestedBatchSizes: [3, 3, 3, 3, 3, 3, 2],
      decodedBatchSizes: [3, 3, 3, 2, 3, 3, 2],
    );
    final diagnostics = PaperGenerationDiagnostics.fromCollection(
      collection,
      schemaRejectedCount: 1,
      policyRejectedCount: 1,
      finalCount: 16,
      quotaRejectedCount: 2,
      typeTargets: const {'choice': 12, 'fill': 8},
      typeAccepted: const {'choice': 12, 'fill': 4},
      typeMissing: const {'fill': 4},
    );
    final result = PaperGenerationResult<int>(
      status: PaperGenerationStatus.partial,
      items: List.generate(16, (index) => index),
      diagnostics: diagnostics,
    );

    expect(result.missingCount, 4);
    expect(diagnostics.modelDecodedCount, 19);
    expect(diagnostics.schemaRejectedCount, 1);
    expect(diagnostics.policyRejectedCount, 1);
    expect(diagnostics.duplicateRejectedCount, 1);
    expect(diagnostics.quotaRejectedCount, 2);
    expect(diagnostics.typeQuotaSatisfied, isFalse);
    expect(diagnostics.typeMissing, {'fill': 4});
  });
}
