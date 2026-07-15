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
  Future<dynamic> setLanguage(String value) async => language = value;
  @override
  Future<dynamic> setSpeechRate(double value) async => speechRate = value;
  @override
  Future<dynamic> setVolume(double value) async => 1;
  @override
  Future<dynamic> setPitch(double value) async => 1;
  @override
  Future<dynamic> speak(String text) async {
    if (throwOnSpeak) throw StateError('tts unavailable');
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
    onCancel?.call();
    return 1;
  }
}

void main() {
  test('plays with normalized language and can pause', () async {
    final engine = _FakeTtsEngine();
    final service = ListeningAudioService(engine: engine);

    await service.play('Hello world', locale: 'en-GB');
    expect(engine.language, 'en-US');
    expect(engine.spokenText, 'Hello world');
    expect(service.state, ListeningPlaybackState.playing);

    await service.pause();
    expect(service.state, ListeningPlaybackState.paused);
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
}
