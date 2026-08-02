import 'package:ai_question_bank_android/features/service_mode/service_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to BYOK and persists official mode', () async {
    const controller = ServiceModeController();

    expect(await controller.load(), AiServiceMode.byok);
    await controller.save(AiServiceMode.official);
    expect(await controller.load(), AiServiceMode.official);
  });

  test('unknown stored mode safely falls back to BYOK', () {
    expect(AiServiceModeValue.parse('unexpected'), AiServiceMode.byok);
  });
}
