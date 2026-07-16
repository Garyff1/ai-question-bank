import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_question_bank_android/features/audio/listening_audio_service.dart';

class _FakeTtsEngine implements ListeningTtsEngine {
  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onPause;
  VoidCallback? onCancel;
  ValueChanged<dynamic>? onError;
  String? language;
  String? spokenText;
  double? speechRate;
  bool throwOnSpeak = false;
  Completer<void>? languageGate;
  int speakCount = 0;
  int stopCount = 0;

  @override
  void setStartHandler(VoidCallback handler) => onStart = handler;
  @override
  void setCompletionHandler(VoidCallback handler) => onComplete = handler;
  @override
  void setPauseHandler(VoidCallback handler) => onPause = handler;
  @override
  void setCancelHandler(VoidCallback handler) => onCancel = handler;
  @override
  void setErrorHandler(ValueChanged<dynamic> handler) => onError = handler;
  @override
  Future<dynamic> setLanguage(String value) async {
    await languageGate?.future;
    language = value;
  }

  @override
  Future<dynamic> setSpeechRate(double value) async => speechRate = value;
  @override
  Future<dynamic> setVolume(double value) async => 1;
  @override
  Future<dynamic> setPitch(double value) async => 1;
  @override
  Future<dynamic> speak(String text) async {
    if (throwOnSpeak) throw StateError('tts unavailable');
    speakCount++;
    spokenText = text;
    onStart?.call();
    return 1;
  }

  @override
  Future<dynamic> pause() async {
    onPause?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCount++;
    onCancel?.call();
    return 1;
  }
}

void main() {
  test(
    'plays Chinese, English and mixed text with normalized locales',
    () async {
      final engine = _FakeTtsEngine();
      final service = ListeningAudioService(engine: engine);

      await service.play('你好，世界');
      expect(engine.language, 'zh-CN');
      await service.play('Hello world', locale: 'en-GB');
      expect(engine.language, 'en-US');
      await service.play('人工智能 AI learning');
      expect(engine.language, 'zh-CN');
      expect(engine.spokenText, '人工智能 AI learning');
      service.dispose();
    },
  );

  test('supports pause, stop and replay', () async {
    final engine = _FakeTtsEngine();
    final service = ListeningAudioService(engine: engine);

    await service.play('Hello world', locale: 'en-US');
    expect(service.state, ListeningPlaybackState.playing);
    await service.pause();
    expect(service.state, ListeningPlaybackState.paused);
    await service.stop();
    expect(service.state, ListeningPlaybackState.idle);
    await service.replay();
    expect(engine.spokenText, 'Hello world');
    expect(engine.speakCount, 2);
    service.dispose();
  });

  test('supports three rates and clamps unsafe values', () async {
    final engine = _FakeTtsEngine();
    final service = ListeningAudioService(engine: engine);

    for (final rate in [0.32, 0.48, 0.62]) {
      await service.setRate(rate);
      expect(service.rate, rate);
      expect(engine.speechRate, rate);
    }
    await service.setRate(9);
    expect(service.rate, 0.7);
    await service.setRate(0);
    expect(service.rate, 0.25);
    service.dispose();
  });

  test('rapid repeated play keeps only the newest request', () async {
    final engine = _FakeTtsEngine()..languageGate = Completer<void>();
    final service = ListeningAudioService(engine: engine);

    final first = service.play('第一段');
    await Future<void>.delayed(Duration.zero);
    final second = service.play('第二段');
    engine.languageGate!.complete();
    await Future.wait([first, second]);

    expect(engine.spokenText, '第二段');
    expect(engine.speakCount, 1);
    service.dispose();
  });

  test('empty or failed speech degrades without throwing', () async {
    final engine = _FakeTtsEngine();
    final service = ListeningAudioService(engine: engine);

    await service.play('  ');
    expect(service.state, ListeningPlaybackState.error);
    expect(service.errorMessage, isNotEmpty);

    engine.throwOnSpeak = true;
    await service.play('测试语音');
    expect(service.state, ListeningPlaybackState.error);
    expect(service.errorMessage, contains('继续阅读'));
    service.dispose();
  });

  test('dispose cancels pending speech without notifying afterwards', () async {
    final engine = _FakeTtsEngine()..languageGate = Completer<void>();
    final service = ListeningAudioService(engine: engine);
    final pending = service.play('离开页面后不应继续播放');
    await Future<void>.delayed(Duration.zero);
    service.dispose();
    engine.languageGate!.complete();
    await pending;
    expect(engine.speakCount, 0);
  });
}
