import 'dart:convert';

/// 解析大模型返回的对象数组，并对末尾被截断的响应做安全降级。
///
/// 大模型可能附带 Markdown 围栏，也可能在最后一道题中途停止。完整 JSON
/// 解析失败时，只提取已经闭合的顶层对象，不把 [FormatException] 暴露给用户。
class AiJsonParser {
  const AiJsonParser._();

  static List<Map<String, dynamic>> decodeObjectList(
    String raw, {
    List<String> rootKeys = const ['questions', 'games', 'items'],
  }) {
    final cleaned = _stripCodeFence(raw);
    if (cleaned.isEmpty) return const [];

    final direct = _decodeDirect(cleaned, rootKeys);
    if (direct.isNotEmpty) return direct;

    return _salvageCompleteObjects(cleaned);
  }

  static List<Map<String, dynamic>> _decodeDirect(
    String text,
    List<String> rootKeys,
  ) {
    final candidates = <String>[text];
    final firstArray = text.indexOf('[');
    final lastArray = text.lastIndexOf(']');
    if (firstArray >= 0 && lastArray > firstArray) {
      candidates.add(text.substring(firstArray, lastArray + 1));
    }
    final firstObject = text.indexOf('{');
    final lastObject = text.lastIndexOf('}');
    if (firstObject >= 0 && lastObject > firstObject) {
      candidates.add(text.substring(firstObject, lastObject + 1));
    }

    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        final list = _listFromDecoded(decoded, rootKeys);
        if (list.isNotEmpty) return list;
      } on FormatException {
        // 继续尝试完整对象提取。
      }
    }
    return const [];
  }

  static List<Map<String, dynamic>> _listFromDecoded(
    Object? decoded,
    List<String> rootKeys,
  ) {
    Object? value = decoded;
    if (decoded is Map) {
      var foundRootList = false;
      for (final key in rootKeys) {
        final candidate = decoded[key];
        if (candidate is List) {
          value = candidate;
          foundRootList = true;
          break;
        }
      }
      // 部分 OpenAI 兼容模型在被要求返回数组时，偶尔只返回一个完整对象。
      // 把它视为一条有效结果，交由上层分批补齐，而不是直接判定为格式错误。
      if (!foundRootList && _looksLikeGeneratedItem(decoded)) {
        value = [decoded];
      }
    }
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static bool _looksLikeGeneratedItem(Map<dynamic, dynamic> value) {
    return const [
      'question',
      'title',
      'prompt',
      'game_type',
    ].any((key) => (value[key] ?? '').toString().trim().isNotEmpty);
  }

  /// 从第一个数组中提取已经完整闭合的直接子对象。嵌套的 rich_content / data
  /// 会随父对象保留，不会被误当成独立题目。
  static List<Map<String, dynamic>> _salvageCompleteObjects(String text) {
    final arrayStart = text.indexOf('[');
    if (arrayStart < 0) return const [];

    final result = <Map<String, dynamic>>[];
    var inString = false;
    var escaped = false;
    var objectDepth = 0;
    var objectStart = -1;

    for (var index = arrayStart + 1; index < text.length; index++) {
      final char = text[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        if (objectDepth == 0) objectStart = index;
        objectDepth++;
      } else if (char == '}' && objectDepth > 0) {
        objectDepth--;
        if (objectDepth == 0 && objectStart >= 0) {
          final objectText = text.substring(objectStart, index + 1);
          try {
            final decoded = jsonDecode(objectText);
            if (decoded is Map) {
              result.add(Map<String, dynamic>.from(decoded));
            }
          } on FormatException {
            // 当前对象不完整时忽略；之前完整的题目仍然可用。
          }
          objectStart = -1;
        }
      }
    }
    return result;
  }

  static String _stripCodeFence(String raw) {
    var text = raw.trim();
    text = text.replaceFirst(
      RegExp(r'^```(?:json)?\s*', caseSensitive: false),
      '',
    );
    text = text.replaceFirst(RegExp(r'\s*```\s*$'), '');
    return text.trim();
  }
}

/// 将长题目生成任务拆成多个短 JSON 批次，并合并为指定数量。
///
/// 许多兼容 OpenAI 的模型会在一次返回 10—30 个复杂对象时截断 JSON。
/// 收集器限制单批数量、过滤无效对象并去重；是否接受不足数量的结果由调用方
/// 决定。这样 UI 不会再把“成功解析到 1 道”误当成“10 道生成完成”。
class AiJsonBatchCollector {
  const AiJsonBatchCollector._();

  static Future<List<Map<String, dynamic>>> collect({
    required int expectedCount,
    required Future<String> Function(
      int requestedCount,
      int requestNumber,
      List<Map<String, dynamic>> collected,
    )
    request,
    List<String> rootKeys = const ['questions', 'games', 'items'],
    int maxBatchSize = 5,
    int? maxRequests,
    bool Function(Map<String, dynamic> value)? isValid,
    String Function(Map<String, dynamic> value)? identityOf,
    bool requireExact = true,
  }) async {
    if (expectedCount <= 0) return const [];
    if (maxBatchSize <= 0) {
      throw ArgumentError.value(maxBatchSize, 'maxBatchSize');
    }

    final collected = <Map<String, dynamic>>[];
    final identities = <String>{};
    final minimumRequests = (expectedCount + maxBatchSize - 1) ~/ maxBatchSize;
    final requestLimit = maxRequests ?? (minimumRequests + 2);
    var requestNumber = 0;
    var consecutiveEmptyResponses = 0;

    while (collected.length < expectedCount &&
        requestNumber < requestLimit &&
        consecutiveEmptyResponses < 2) {
      requestNumber++;
      final remaining = expectedCount - collected.length;
      final requestedCount = remaining < maxBatchSize
          ? remaining
          : maxBatchSize;
      final raw = await request(
        requestedCount,
        requestNumber,
        List<Map<String, dynamic>>.unmodifiable(collected),
      );
      final decoded = AiJsonParser.decodeObjectList(raw, rootKeys: rootKeys);
      final before = collected.length;

      for (final value in decoded) {
        if (isValid != null && !isValid(value)) continue;
        final identity = identityOf?.call(value) ?? jsonEncode(value);
        if (identities.add(identity)) collected.add(value);
        if (collected.length >= expectedCount) break;
      }

      if (collected.length == before) {
        consecutiveEmptyResponses++;
      } else {
        consecutiveEmptyResponses = 0;
      }
    }

    final result = collected.take(expectedCount).toList(growable: false);
    if (requireExact && result.length < expectedCount) {
      throw AiJsonIncompleteException(
        expectedCount: expectedCount,
        actualCount: result.length,
      );
    }
    return result;
  }
}

class AiJsonIncompleteException implements Exception {
  const AiJsonIncompleteException({
    required this.expectedCount,
    required this.actualCount,
  });

  final int expectedCount;
  final int actualCount;

  @override
  String toString() =>
      'AiJsonIncompleteException(expected: $expectedCount, actual: $actualCount)';
}
