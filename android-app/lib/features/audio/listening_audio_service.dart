import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum ListeningPlaybackState { idle, loading, playing, paused, error }

abstract class ListeningTtsEngine {
  void setStartHandler(VoidCallback handler);
  void setCompletionHandler(VoidCallback handler);
  void setPauseHandler(VoidCallback handler);
  void setCancelHandler(VoidCallback handler);
  void setErrorHandler(ValueChanged<dynamic> handler);
  Future<dynamic> setLanguage(String language);
  Future<dynamic> setSpeechRate(double rate);
  Future<dynamic> setVolume(double volume);
  Future<dynamic> setPitch(double pitch);
  Future<dynamic> speak(String text);
  Future<dynamic> pause();
  Future<dynamic> stop();
}

class FlutterListeningTtsEngine implements ListeningTtsEngine {
  FlutterListeningTtsEngine() : _tts = FlutterTts();

  final FlutterTts _tts;

  @override
  void setStartHandler(VoidCallback handler) => _tts.setStartHandler(handler);
  @override
  void setCompletionHandler(VoidCallback handler) =>
      _tts.setCompletionHandler(handler);
  @override
  void setPauseHandler(VoidCallback handler) => _tts.setPauseHandler(handler);
  @override
  void setCancelHandler(VoidCallback handler) => _tts.setCancelHandler(handler);
  @override
  void setErrorHandler(ValueChanged<dynamic> handler) =>
      _tts.setErrorHandler(handler);
  @override
  Future<dynamic> setLanguage(String language) => _tts.setLanguage(language);
  @override
  Future<dynamic> setSpeechRate(double rate) => _tts.setSpeechRate(rate);
  @override
  Future<dynamic> setVolume(double volume) => _tts.setVolume(volume);
  @override
  Future<dynamic> setPitch(double pitch) => _tts.setPitch(pitch);
  @override
  Future<dynamic> speak(String text) => _tts.speak(text);
  @override
  Future<dynamic> pause() => _tts.pause();
  @override
  Future<dynamic> stop() => _tts.stop();
}

class ListeningAudioService extends ChangeNotifier {
  ListeningAudioService({ListeningTtsEngine? engine})
    : _engine = engine ?? FlutterListeningTtsEngine() {
    _engine.setStartHandler(() => _setState(ListeningPlaybackState.playing));
    _engine.setCompletionHandler(() => _setState(ListeningPlaybackState.idle));
    _engine.setPauseHandler(() => _setState(ListeningPlaybackState.paused));
    _engine.setCancelHandler(() => _setState(ListeningPlaybackState.idle));
    _engine.setErrorHandler((message) {
      final text = message?.toString().trim() ?? '';
      errorMessage = text.isEmpty ? '系统语音播放失败' : text;
      _setState(ListeningPlaybackState.error);
    });
  }

  final ListeningTtsEngine _engine;
  ListeningPlaybackState state = ListeningPlaybackState.idle;
  String? errorMessage;
  String _lastText = '';
  String _lastLocale = 'zh-CN';
  double rate = 0.48;

  Future<void> play(String text, {String? locale}) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      errorMessage = '听力原文为空，可继续阅读题目文字作答';
      _setState(ListeningPlaybackState.error);
      return;
    }
    _lastText = normalized;
    _lastLocale = _normalizeLocale(locale);
    errorMessage = null;
    _setState(ListeningPlaybackState.loading);
    try {
      await _engine.stop();
      await _engine.setLanguage(_lastLocale);
      await _engine.setSpeechRate(rate);
      await _engine.setVolume(1.0);
      await _engine.setPitch(1.0);
      final result = await _engine.speak(normalized);
      if (result == 0) {
        throw StateError('设备未能启动系统语音');
      }
      if (state == ListeningPlaybackState.loading) {
        _setState(ListeningPlaybackState.playing);
      }
    } catch (error, stack) {
      debugPrint('[TTS] play failed: $error');
      debugPrintStack(stackTrace: stack);
      errorMessage = '系统语音暂不可用，可继续阅读题目文字或稍后重试';
      _setState(ListeningPlaybackState.error);
    }
  }

  Future<void> replay() => play(_lastText, locale: _lastLocale);

  Future<void> pause() async {
    try {
      await _engine.pause();
      _setState(ListeningPlaybackState.paused);
    } catch (_) {
      await stop();
    }
  }

  Future<void> stop() async {
    try {
      await _engine.stop();
    } finally {
      _setState(ListeningPlaybackState.idle);
    }
  }

  Future<void> setRate(double value) async {
    rate = value.clamp(0.25, 0.7);
    await _engine.setSpeechRate(rate);
    notifyListeners();
  }

  String _normalizeLocale(String? value) {
    final locale = (value ?? '').toLowerCase();
    if (locale.startsWith('en')) return 'en-US';
    if (locale.startsWith('zh')) return 'zh-CN';
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(_lastText)) return 'zh-CN';
    return 'en-US';
  }

  void _setState(ListeningPlaybackState value) {
    state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _engine.stop();
    super.dispose();
  }
}
