import 'dart:async';

import 'package:ai_question_bank_android/core/ai_guard/ai_request_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fast duplicate task is blocked and only one action runs', () async {
    final guard = AiRequestGuard();
    final completer = Completer<void>();
    var runs = 0;
    final first = guard.runTask<void>(
      taskType: 'question_generation',
      provider: 'deepseek',
      model: 'deepseek-chat',
      targetCount: 5,
      fingerprint: 'same',
      action: (_) async {
        runs++;
        await completer.future;
      },
    );

    await expectLater(
      guard.runTask<void>(
        taskType: 'question_generation',
        provider: 'deepseek',
        model: 'deepseek-chat',
        targetCount: 5,
        fingerprint: 'same',
        action: (_) async {
          runs++;
        },
      ),
      throwsA(isA<AiTaskBlockedException>()),
    );
    completer.complete();
    await first;
    expect(runs, 1);
  });

  test('cancel prevents late result from being accepted', () async {
    final guard = AiRequestGuard();
    final started = Completer<void>();
    final release = Completer<void>();
    final task = guard.runTask<String>(
      taskType: 'paper_generation',
      provider: 'qwen',
      model: 'qwen-plus',
      targetCount: 20,
      fingerprint: 'cancel-me',
      action: (handle) async {
        started.complete();
        await release.future;
        return 'late result';
      },
    );
    await started.future;
    expect(guard.cancelActiveTask(), isTrue);
    release.complete();
    await expectLater(task, throwsA(isA<AiTaskCancelledException>()));
    final records = await guard.loadRecords();
    expect(records.single.status, AiTaskStatus.cancelled);
  });

  test('usage records never contain prompt or API key fields', () async {
    final guard = AiRequestGuard();
    await guard.runTask<void>(
      taskType: 'connection_test',
      provider: 'custom',
      model: 'model',
      targetCount: 0,
      fingerprint: 'safe-record',
      action: (_) async {
        guard.beforeNetworkRequest();
        guard.recordUsage(inputTokens: 12, outputTokens: 3);
      },
    );
    final raw = (await SharedPreferences.getInstance()).getString(
      'ai_usage_records_v1',
    )!;
    expect(raw, isNot(contains('apiKey')));
    expect(raw, isNot(contains('prompt')));
    expect(raw, contains('inputTokens'));
  });

  test('a task cannot create an unbounded request chain', () async {
    final guard = AiRequestGuard();
    await expectLater(
      guard.runTask<void>(
        taskType: 'connection_test',
        provider: 'custom',
        model: 'model',
        targetCount: 0,
        fingerprint: 'bounded',
        action: (_) async {
          guard.beforeNetworkRequest();
          guard.beforeNetworkRequest(retry: true);
          guard.beforeNetworkRequest(retry: true);
        },
      ),
      throwsA(isA<AiTaskBlockedException>()),
    );
    final record = (await guard.loadRecords()).single;
    expect(record.status, AiTaskStatus.blocked);
    expect(record.requestCount, 2);
  });

  test('daily reminder is shown at most once per day', () async {
    final guard = AiRequestGuard();
    await guard.savePreferences(
      const AiGuardPreferences(dailyReminderThreshold: 1),
    );
    await guard.runTask<void>(
      taskType: 'question_generation',
      provider: 'deepseek',
      model: 'deepseek-chat',
      targetCount: 5,
      fingerprint: 'daily',
      action: (_) async {},
    );

    expect(await guard.shouldShowDailyReminder(), isTrue);
    await guard.markDailyReminderShown();
    expect(await guard.shouldShowDailyReminder(), isFalse);
  });
}
