import 'package:flutter/services.dart';

class SecureScreen {
  static const _channel = MethodChannel('ai_question_bank/secure_screen');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod<void>('enable');
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } catch (_) {}
  }
}
