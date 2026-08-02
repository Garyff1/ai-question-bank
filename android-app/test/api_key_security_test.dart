import 'package:ai_question_bank_android/core/security/api_key_masking.dart';
import 'package:ai_question_bank_android/core/security/secure_log_filter.dart';
import 'package:ai_question_bank_android/core/security/secret_visibility_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API Key masking never exposes the complete value', () {
    const secret = 'sk-super-secret-value-123456';
    final masked = maskApiKey(secret);

    expect(masked, isNot(secret));
    expect(masked, endsWith('3456'));
    expect(masked, isNot(contains('super-secret-value')));
  });

  test('log filter redacts bearer, named keys and sk tokens', () {
    const secret = 'sk-example-secret-123456789';
    final output = redactSensitiveText(
      'Authorization: Bearer $secret api_key=$secret password=hunter2',
    );

    expect(output, isNot(contains(secret)));
    expect(output, isNot(contains('hunter2')));
    expect(output, contains('REDACTED'));
  });

  test('safe API error keeps useful status without secret', () {
    const secret = 'sk-example-secret-123456789';
    final output = safeApiErrorMessage(
      Exception('401 authorization=Bearer $secret'),
    );

    expect(output, contains('401'));
    expect(output, isNot(contains(secret)));
  });

  testWidgets('temporary reveal hides immediately when app leaves foreground', (
    tester,
  ) async {
    final controller = SecretVisibilityController(
      visibleDuration: const Duration(minutes: 1),
    );
    addTearDown(controller.dispose);

    controller.revealTemporarily();
    expect(controller.visible, isTrue);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(controller.visible, isFalse);
  });
}
