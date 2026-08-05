import 'package:ai_question_bank_android/core/platform/generation_wake_lock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generation wake lock is reference counted', () async {
    const channel = MethodChannel('ai_question_bank/generation_wake_lock');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await GenerationWakeLock.acquire();
    await GenerationWakeLock.acquire();
    await GenerationWakeLock.release();
    expect(calls, ['enable']);

    await GenerationWakeLock.release();
    expect(calls, ['enable', 'disable']);
  });
}
