class OfficialFeatureFlags {
  const OfficialFeatureFlags({
    required this.officialAiEnabled,
    required this.shadowBillingEnabled,
    required this.paymentMockEnabled,
    required this.wechatPayEnabled,
    required this.alipayPayEnabled,
    required this.realChargeEnabled,
    required this.environment,
  });

  final bool officialAiEnabled;
  final bool shadowBillingEnabled;
  final bool paymentMockEnabled;
  final bool wechatPayEnabled;
  final bool alipayPayEnabled;
  final bool realChargeEnabled;
  final String environment;

  factory OfficialFeatureFlags.fromJson(Map<String, dynamic> json) =>
      OfficialFeatureFlags(
        officialAiEnabled: json['officialAiEnabled'] == true,
        shadowBillingEnabled: json['shadowBillingEnabled'] == true,
        paymentMockEnabled: json['paymentMockEnabled'] == true,
        wechatPayEnabled: json['wechatPayEnabled'] == true,
        alipayPayEnabled: json['alipayPayEnabled'] == true,
        realChargeEnabled: json['realChargeEnabled'] == true,
        environment: json['environment'] as String? ?? 'test',
      );
}

class OfficialQuoteItem {
  const OfficialQuoteItem({
    required this.code,
    required this.labelZh,
    required this.labelEn,
    required this.amountFen,
    required this.free,
  });

  final String code;
  final String labelZh;
  final String labelEn;
  final int amountFen;
  final bool free;

  factory OfficialQuoteItem.fromJson(Map<String, dynamic> json) =>
      OfficialQuoteItem(
        code: json['code'] as String? ?? '',
        labelZh: json['labelZh'] as String? ?? '',
        labelEn: json['labelEn'] as String? ?? '',
        amountFen: (json['amountFen'] as num?)?.toInt() ?? 0,
        free: json['free'] == true,
      );
}

class OfficialQuote {
  const OfficialQuote({
    required this.id,
    required this.questionCount,
    required this.amountFen,
    required this.currency,
    required this.items,
    required this.expiresAt,
  });

  final String id;
  final int questionCount;
  final int amountFen;
  final String currency;
  final List<OfficialQuoteItem> items;
  final DateTime? expiresAt;

  factory OfficialQuote.fromJson(Map<String, dynamic> json) => OfficialQuote(
    id: json['quoteId'] as String? ?? '',
    questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    amountFen: (json['amountFen'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String? ?? 'CNY',
    items: (json['breakdown'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => OfficialQuoteItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
  );
}

class OfficialOrder {
  const OfficialOrder({
    required this.id,
    required this.questionCount,
    required this.amountFen,
    required this.paymentChannel,
    required this.status,
    required this.isTest,
    required this.createdAt,
    this.failureReason,
    this.result = const [],
  });

  final String id;
  final int questionCount;
  final int amountFen;
  final String paymentChannel;
  final String status;
  final bool isTest;
  final DateTime? createdAt;
  final String? failureReason;
  final List<dynamic> result;

  bool get terminal => const {'success', 'refunded', 'closed'}.contains(status);

  factory OfficialOrder.fromJson(Map<String, dynamic> json) => OfficialOrder(
    id: json['orderId'] as String? ?? '',
    questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    amountFen: (json['amountFen'] as num?)?.toInt() ?? 0,
    paymentChannel: json['paymentChannel'] as String? ?? 'mock',
    status: json['status'] as String? ?? 'pending',
    isTest: json['isTest'] != false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    failureReason: json['failureReason'] as String?,
    result: json['result'] is List
        ? List<dynamic>.from(json['result'] as List)
        : const [],
  );
}

class OfficialUsage {
  const OfficialUsage({
    required this.orderId,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.estimatedCostFen,
    required this.quotedAmountFen,
    required this.success,
  });

  final String? orderId;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int estimatedCostFen;
  final int quotedAmountFen;
  final bool success;

  factory OfficialUsage.fromJson(Map<String, dynamic> json) => OfficialUsage(
    orderId: json['orderId'] as String?,
    model: json['model'] as String? ?? '',
    inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
    outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
    estimatedCostFen: (json['estimatedCostFen'] as num?)?.toInt() ?? 0,
    quotedAmountFen: (json['quotedAmountFen'] as num?)?.toInt() ?? 0,
    success: json['success'] == true,
  );
}

String formatFen(int fen) => '¥${(fen / 100).toStringAsFixed(2)}';
