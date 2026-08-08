import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum AiTaskStatus { success, failed, cancelled, blocked }

class AiTaskCancelledException implements Exception {
  const AiTaskCancelledException();

  @override
  String toString() => 'AI 任务已取消';
}

class AiTaskBlockedException implements Exception {
  const AiTaskBlockedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiUsageRecord {
  const AiUsageRecord({
    required this.taskId,
    required this.createdAt,
    required this.taskType,
    required this.provider,
    required this.model,
    required this.requestCount,
    required this.retryCount,
    required this.status,
    required this.targetCount,
    this.inputTokens,
    this.outputTokens,
    this.errorCategory,
  });

  final String taskId;
  final DateTime createdAt;
  final String taskType;
  final String provider;
  final String model;
  final int requestCount;
  final int retryCount;
  final AiTaskStatus status;
  final int targetCount;
  final int? inputTokens;
  final int? outputTokens;
  final String? errorCategory;

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'createdAt': createdAt.toIso8601String(),
    'taskType': taskType,
    'provider': provider,
    'model': model,
    'requestCount': requestCount,
    'retryCount': retryCount,
    'status': status.name,
    'targetCount': targetCount,
    if (inputTokens != null) 'inputTokens': inputTokens,
    if (outputTokens != null) 'outputTokens': outputTokens,
    if (errorCategory != null) 'errorCategory': errorCategory,
  };

  factory AiUsageRecord.fromJson(Map<String, dynamic> json) => AiUsageRecord(
    taskId: (json['taskId'] ?? '').toString(),
    createdAt:
        DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    taskType: (json['taskType'] ?? 'unknown').toString(),
    provider: (json['provider'] ?? 'unknown').toString(),
    model: (json['model'] ?? 'unknown').toString(),
    requestCount: (json['requestCount'] as num?)?.toInt() ?? 0,
    retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    status: AiTaskStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => AiTaskStatus.failed,
    ),
    targetCount: (json['targetCount'] as num?)?.toInt() ?? 0,
    inputTokens: (json['inputTokens'] as num?)?.toInt(),
    outputTokens: (json['outputTokens'] as num?)?.toInt(),
    errorCategory: json['errorCategory']?.toString(),
  );
}

class AiGuardPreferences {
  const AiGuardPreferences({
    this.autoRetry = true,
    this.largeTaskWarning = true,
    this.showUsageRecords = true,
    this.confirmRegularAi = true,
    this.dailyReminderThreshold = 20,
  });

  final bool autoRetry;
  final bool largeTaskWarning;
  final bool showUsageRecords;
  final bool confirmRegularAi;
  final int dailyReminderThreshold;

  AiGuardPreferences copyWith({
    bool? autoRetry,
    bool? largeTaskWarning,
    bool? showUsageRecords,
    bool? confirmRegularAi,
    int? dailyReminderThreshold,
  }) => AiGuardPreferences(
    autoRetry: autoRetry ?? this.autoRetry,
    largeTaskWarning: largeTaskWarning ?? this.largeTaskWarning,
    showUsageRecords: showUsageRecords ?? this.showUsageRecords,
    confirmRegularAi: confirmRegularAi ?? this.confirmRegularAi,
    dailyReminderThreshold:
        dailyReminderThreshold ?? this.dailyReminderThreshold,
  );
}

class AiTaskHandle {
  AiTaskHandle._({
    required this.taskId,
    required this.createdAt,
    required this.taskType,
    required this.provider,
    required this.model,
    required this.targetCount,
    required this.fingerprint,
  });

  final String taskId;
  final DateTime createdAt;
  final String taskType;
  final String provider;
  final String model;
  final int targetCount;
  final String fingerprint;

  int requestCount = 0;
  int retryCount = 0;
  int? inputTokens;
  int? outputTokens;
  bool cancelled = false;

  void throwIfCancelled() {
    if (cancelled) throw const AiTaskCancelledException();
  }
}

class AiRequestGuard {
  AiRequestGuard();

  static final AiRequestGuard instance = AiRequestGuard();

  static const _recordsKey = 'ai_usage_records_v1';
  static const _autoRetryKey = 'ai_guard.auto_retry_v1';
  static const _largeWarningKey = 'ai_guard.large_warning_v1';
  static const _showRecordsKey = 'ai_guard.show_records_v1';
  static const _confirmRegularKey = 'ai_guard.confirm_regular_v1';
  static const _dailyThresholdKey = 'ai_guard.daily_threshold_v1';
  static const _dailyNoticeDateKey = 'ai_guard.daily_notice_date_v1';
  static const int maxStoredRecords = 200;
  static const int maxStartsPerMinute = 12;

  final Map<String, DateTime> _recentFingerprints = <String, DateTime>{};
  final List<DateTime> _recentStarts = <DateTime>[];
  AiTaskHandle? _activeTask;
  void Function()? _cancelNetwork;
  bool _circuitOpen = false;

  AiTaskHandle? get activeTask => _activeTask;
  bool get circuitOpen => _circuitOpen;

  static String fingerprint(Iterable<Object?> values) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offset;
    for (final unit in utf8.encode(values.join('|'))) {
      hash ^= unit;
      hash = (hash * prime) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Future<T> runTask<T>({
    required String taskType,
    required String provider,
    required String model,
    required int targetCount,
    required String fingerprint,
    required Future<T> Function(AiTaskHandle task) action,
  }) async {
    final now = DateTime.now();
    _prune(now);
    if (_circuitOpen) {
      throw const AiTaskBlockedException(
        '检测到异常连续请求，AI 调用已暂停。请先查看 API 使用记录后手动恢复。',
      );
    }
    if (_activeTask != null) {
      throw const AiTaskBlockedException('已有 AI 任务正在进行，请等待完成或先取消当前任务。');
    }
    final previous = _recentFingerprints[fingerprint];
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 3)) {
      throw const AiTaskBlockedException('已拦截短时间内的重复生成请求。');
    }
    if (_recentStarts.length >= maxStartsPerMinute) {
      _circuitOpen = true;
      throw const AiTaskBlockedException('一分钟内请求次数异常，为保护 API 额度已暂停 AI 调用。');
    }

    final task = AiTaskHandle._(
      taskId: _newTaskId(now),
      createdAt: now,
      taskType: taskType,
      provider: provider,
      model: model,
      targetCount: targetCount,
      fingerprint: fingerprint,
    );
    _activeTask = task;
    _recentStarts.add(now);
    _recentFingerprints[fingerprint] = now;
    try {
      final result = await action(task);
      task.throwIfCancelled();
      await _saveRecord(task, AiTaskStatus.success);
      return result;
    } on AiTaskCancelledException {
      await _saveRecord(task, AiTaskStatus.cancelled);
      rethrow;
    } on AiTaskBlockedException {
      await _saveRecord(
        task,
        AiTaskStatus.blocked,
        errorCategory: 'request_guard',
      );
      rethrow;
    } catch (error) {
      await _saveRecord(
        task,
        AiTaskStatus.failed,
        errorCategory: _classifyError(error),
      );
      rethrow;
    } finally {
      _cancelNetwork = null;
      if (identical(_activeTask, task)) _activeTask = null;
    }
  }

  void beforeNetworkRequest({bool retry = false}) {
    final task = _activeTask;
    if (task == null) return;
    task.throwIfCancelled();
    if (task.requestCount >= _requestLimit(task.targetCount)) {
      throw const AiTaskBlockedException(
        '本任务的网络请求次数已达到安全上限。为保护 API 额度，已停止继续请求。',
      );
    }
    task.requestCount++;
    if (retry) task.retryCount++;
  }

  void registerNetworkCancellation(void Function() cancel) {
    _cancelNetwork = cancel;
    _activeTask?.throwIfCancelled();
  }

  void clearNetworkCancellation() => _cancelNetwork = null;

  void recordUsage({int? inputTokens, int? outputTokens}) {
    final task = _activeTask;
    if (task == null) return;
    if (inputTokens != null) {
      task.inputTokens = (task.inputTokens ?? 0) + inputTokens;
    }
    if (outputTokens != null) {
      task.outputTokens = (task.outputTokens ?? 0) + outputTokens;
    }
  }

  void throwIfCancelled() => _activeTask?.throwIfCancelled();

  bool cancelActiveTask() {
    final task = _activeTask;
    if (task == null) return false;
    task.cancelled = true;
    _cancelNetwork?.call();
    _cancelNetwork = null;
    return true;
  }

  void resumeAfterCircuitBreak() {
    _circuitOpen = false;
    _recentStarts.clear();
  }

  Future<AiGuardPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return AiGuardPreferences(
      autoRetry: prefs.getBool(_autoRetryKey) ?? true,
      largeTaskWarning: prefs.getBool(_largeWarningKey) ?? true,
      showUsageRecords: prefs.getBool(_showRecordsKey) ?? true,
      confirmRegularAi: prefs.getBool(_confirmRegularKey) ?? true,
      dailyReminderThreshold: prefs.getInt(_dailyThresholdKey) ?? 20,
    );
  }

  Future<void> savePreferences(AiGuardPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_autoRetryKey, value.autoRetry),
      prefs.setBool(_largeWarningKey, value.largeTaskWarning),
      prefs.setBool(_showRecordsKey, value.showUsageRecords),
      prefs.setBool(_confirmRegularKey, value.confirmRegularAi),
      prefs.setInt(_dailyThresholdKey, value.dailyReminderThreshold),
    ]);
  }

  Future<List<AiUsageRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => AiUsageRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
  }

  Future<int> todayTaskCount() async {
    final now = DateTime.now();
    final records = await loadRecords();
    return records.where((record) {
      final date = record.createdAt;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
  }

  Future<bool> shouldShowDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final threshold = prefs.getInt(_dailyThresholdKey) ?? 20;
    if (threshold <= 0 || await todayTaskCount() < threshold) return false;
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    return prefs.getString(_dailyNoticeDateKey) != today;
  }

  Future<void> markDailyReminderShown() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(
      _dailyNoticeDateKey,
      '${now.year}-${now.month}-${now.day}',
    );
  }

  Future<void> _saveRecord(
    AiTaskHandle task,
    AiTaskStatus status, {
    String? errorCategory,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await loadRecords();
    final updated = <AiUsageRecord>[
      AiUsageRecord(
        taskId: task.taskId,
        createdAt: task.createdAt,
        taskType: task.taskType,
        provider: task.provider,
        model: task.model,
        requestCount: task.requestCount,
        retryCount: task.retryCount,
        status: status,
        targetCount: task.targetCount,
        inputTokens: task.inputTokens,
        outputTokens: task.outputTokens,
        errorCategory: errorCategory,
      ),
      ...records,
    ].take(maxStoredRecords).toList(growable: false);
    await prefs.setString(
      _recordsKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  void _prune(DateTime now) {
    _recentStarts.removeWhere(
      (value) => now.difference(value) > const Duration(minutes: 1),
    );
    _recentFingerprints.removeWhere(
      (_, value) => now.difference(value) > const Duration(seconds: 10),
    );
  }

  String _newTaskId(DateTime now) {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return '${now.millisecondsSinceEpoch.toRadixString(16)}-$random';
  }

  int _requestLimit(int targetCount) {
    if (targetCount <= 0) return 2;
    // Batch generation uses small repair requests when a provider truncates
    // JSON. Keep enough headroom for a legitimate task, but never allow an
    // unbounded request chain.
    return (((targetCount + 2) ~/ 3) + 3).clamp(4, 16).toInt();
  }

  String _classifyError(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('401') || value.contains('api key')) {
      return 'authentication';
    }
    if (value.contains('403')) return 'permission';
    if (value.contains('429') || value.contains('rate')) return 'rate_limit';
    if (value.contains('timeout')) return 'timeout';
    if (value.contains('socket') || value.contains('handshake')) {
      return 'network';
    }
    if (value.contains('json') || value.contains('format')) {
      return 'invalid_output';
    }
    return 'unknown';
  }
}
