import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 生成题目/试卷时临时保持屏幕常亮。
///
/// 使用引用计数避免嵌套任务提前释放；原生通道异常只记录日志，不阻塞生成。
class GenerationWakeLock {
  GenerationWakeLock._();

  static const MethodChannel _channel = MethodChannel(
    'ai_question_bank/generation_wake_lock',
  );
  static int _holders = 0;

  static Future<void> acquire() async {
    _holders++;
    if (_holders != 1) return;
    try {
      await _channel.invokeMethod<void>('enable');
    } on PlatformException catch (error) {
      debugPrint('[WakeLock] enable failed: ${error.code}');
    } on MissingPluginException {
      debugPrint('[WakeLock] native channel unavailable');
    }
  }

  static Future<void> release() async {
    if (_holders > 0) _holders--;
    if (_holders != 0) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } on PlatformException catch (error) {
      debugPrint('[WakeLock] disable failed: ${error.code}');
    } on MissingPluginException {
      debugPrint('[WakeLock] native channel unavailable');
    }
  }
}
