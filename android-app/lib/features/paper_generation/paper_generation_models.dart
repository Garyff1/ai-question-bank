import '../../core/ai/ai_json_parser.dart';

enum PaperGenerationStatus { success, partial, failed, cancelled }

class PaperGenerationPlan {
  const PaperGenerationPlan({
    required this.targetCount,
    this.maxBatchSize = 3,
    this.safetyExtraRequests = 2,
  });

  final int targetCount;
  final int maxBatchSize;
  final int safetyExtraRequests;

  List<int> get batches {
    if (targetCount <= 0) return const [];
    final result = <int>[];
    var remaining = targetCount;
    while (remaining > 0) {
      final size = remaining < maxBatchSize ? remaining : maxBatchSize;
      result.add(size);
      remaining -= size;
    }
    return result;
  }

  /// 除计划批次外，仅为一次结构修复和一次瞬时失败保留额度。
  int get safeRequestLimit => batches.length + safetyExtraRequests;
}

class PaperGenerationDiagnostics {
  const PaperGenerationDiagnostics({
    required this.targetCount,
    required this.modelDecodedCount,
    required this.schemaValidCount,
    required this.schemaRejectedCount,
    required this.policyRejectedCount,
    required this.duplicateRejectedCount,
    required this.finalCount,
    required this.requestCount,
    required this.requestedBatchSizes,
    required this.decodedBatchSizes,
    this.quotaRejectedCount = 0,
    this.typeTargets = const {},
    this.typeAccepted = const {},
    this.typeMissing = const {},
    this.interruptedByRequestFailure = false,
    this.failedRequestCount = 0,
  });

  final int targetCount;
  final int modelDecodedCount;
  final int schemaValidCount;
  final int schemaRejectedCount;
  final int policyRejectedCount;
  final int duplicateRejectedCount;
  final int finalCount;
  final int requestCount;
  final List<int> requestedBatchSizes;
  final List<int> decodedBatchSizes;
  final int quotaRejectedCount;
  final Map<String, int> typeTargets;
  final Map<String, int> typeAccepted;
  final Map<String, int> typeMissing;
  final bool interruptedByRequestFailure;
  final int failedRequestCount;

  bool get typeQuotaSatisfied =>
      typeMissing.values.every((value) => value <= 0);

  factory PaperGenerationDiagnostics.fromCollection(
    AiJsonCollectionDiagnostics collection, {
    required int schemaRejectedCount,
    required int policyRejectedCount,
    required int finalCount,
    int quotaRejectedCount = 0,
    Map<String, int> typeTargets = const {},
    Map<String, int> typeAccepted = const {},
    Map<String, int> typeMissing = const {},
  }) {
    return PaperGenerationDiagnostics(
      targetCount: collection.expectedCount,
      modelDecodedCount: collection.decodedCount,
      schemaValidCount: collection.decodedCount - schemaRejectedCount,
      schemaRejectedCount: schemaRejectedCount,
      policyRejectedCount: policyRejectedCount,
      duplicateRejectedCount: collection.duplicateCount,
      finalCount: finalCount,
      requestCount: collection.requestCount,
      requestedBatchSizes: collection.requestedBatchSizes,
      decodedBatchSizes: collection.decodedBatchSizes,
      quotaRejectedCount: quotaRejectedCount,
      typeTargets: Map<String, int>.unmodifiable(typeTargets),
      typeAccepted: Map<String, int>.unmodifiable(typeAccepted),
      typeMissing: Map<String, int>.unmodifiable(typeMissing),
      interruptedByRequestFailure: collection.stoppedByRequestFailure,
      failedRequestCount: collection.failedRequestCount,
    );
  }

  Map<String, Object> toJson() => {
    'target': targetCount,
    'modelDecoded': modelDecodedCount,
    'schemaValid': schemaValidCount,
    'schemaRejected': schemaRejectedCount,
    'policyRejected': policyRejectedCount,
    'duplicateRejected': duplicateRejectedCount,
    'final': finalCount,
    'requests': requestCount,
    'requestedBatchSizes': requestedBatchSizes,
    'decodedBatchSizes': decodedBatchSizes,
    'quotaRejected': quotaRejectedCount,
    'typeTargets': typeTargets,
    'typeAccepted': typeAccepted,
    'typeMissing': typeMissing,
    'interruptedByRequestFailure': interruptedByRequestFailure,
    'failedRequests': failedRequestCount,
  };
}

class PaperGenerationResult<T> {
  const PaperGenerationResult({
    required this.status,
    required this.items,
    required this.diagnostics,
  });

  final PaperGenerationStatus status;
  final List<T> items;
  final PaperGenerationDiagnostics diagnostics;

  int get missingCount => (diagnostics.targetCount - items.length).clamp(
    0,
    diagnostics.targetCount,
  );

  bool get isComplete => status == PaperGenerationStatus.success;
}
