import 'package:flutter/material.dart';

import '../core/storage/local_storage.dart';

enum AppThemePreference { system, light, dark }

enum AppLocalePreference { system, zh, en }

enum GenerationLanguage { followMaterial, zh, en }

enum OcrLanguageMode { auto, chinese, english, mixed }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController._(this._storage);

  static const _themeKey = 'settings.theme_v3';
  static const _localeKey = 'settings.locale_v3';
  static const _generationLanguageKey = 'settings.generation_language_v3';
  static const _soundKey = 'settings.sound_v3';
  static const _backgroundSoundKey = 'settings.background_sound_v3';
  static const _hapticsKey = 'settings.haptics_v3';
  static const _reduceMotionKey = 'settings.reduce_motion_v3';
  static const _ocrLanguageKey = 'settings.ocr_language_v3';

  final LocalStorage _storage;

  AppThemePreference _themePreference = AppThemePreference.system;
  AppLocalePreference _localePreference = AppLocalePreference.system;
  GenerationLanguage _generationLanguage = GenerationLanguage.followMaterial;
  bool _soundEnabled = true;
  bool _backgroundSoundEnabled = false;
  bool _hapticsEnabled = true;
  bool _reduceMotion = false;
  OcrLanguageMode _ocrLanguage = OcrLanguageMode.auto;

  static Future<AppSettingsController> load() async {
    final storage = await LocalStorage.create();
    final controller = AppSettingsController._(storage);
    controller._themePreference = _enumValue(
      AppThemePreference.values,
      storage.getString(_themeKey),
      AppThemePreference.system,
    );
    controller._localePreference = _enumValue(
      AppLocalePreference.values,
      storage.getString(_localeKey),
      AppLocalePreference.system,
    );
    controller._generationLanguage = _enumValue(
      GenerationLanguage.values,
      storage.getString(_generationLanguageKey),
      GenerationLanguage.followMaterial,
    );
    controller._soundEnabled = storage.getBool(_soundKey) ?? true;
    controller._backgroundSoundEnabled =
        storage.getBool(_backgroundSoundKey) ?? false;
    controller._hapticsEnabled = storage.getBool(_hapticsKey) ?? true;
    controller._reduceMotion = storage.getBool(_reduceMotionKey) ?? false;
    controller._ocrLanguage = _enumValue(
      OcrLanguageMode.values,
      storage.getString(_ocrLanguageKey),
      OcrLanguageMode.auto,
    );
    return controller;
  }

  AppThemePreference get themePreference => _themePreference;
  AppLocalePreference get localePreference => _localePreference;
  GenerationLanguage get generationLanguage => _generationLanguage;
  bool get soundEnabled => _soundEnabled;
  bool get backgroundSoundEnabled => _backgroundSoundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get reduceMotion => _reduceMotion;
  OcrLanguageMode get ocrLanguage => _ocrLanguage;

  ThemeMode get themeMode => switch (_themePreference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  Locale? get locale => switch (_localePreference) {
    AppLocalePreference.system => null,
    AppLocalePreference.zh => const Locale('zh'),
    AppLocalePreference.en => const Locale('en'),
  };

  Future<void> setThemePreference(AppThemePreference value) async {
    if (_themePreference == value) return;
    _themePreference = value;
    notifyListeners();
    await _storage.setString(_themeKey, value.name);
  }

  Future<void> setLocalePreference(AppLocalePreference value) async {
    if (_localePreference == value) return;
    _localePreference = value;
    notifyListeners();
    await _storage.setString(_localeKey, value.name);
  }

  Future<void> setGenerationLanguage(GenerationLanguage value) async {
    if (_generationLanguage == value) return;
    _generationLanguage = value;
    notifyListeners();
    await _storage.setString(_generationLanguageKey, value.name);
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
    await _storage.setBool(_soundKey, value);
  }

  Future<void> setBackgroundSoundEnabled(bool value) async {
    if (_backgroundSoundEnabled == value) return;
    _backgroundSoundEnabled = value;
    notifyListeners();
    await _storage.setBool(_backgroundSoundKey, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    notifyListeners();
    await _storage.setBool(_hapticsKey, value);
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
    await _storage.setBool(_reduceMotionKey, value);
  }

  Future<void> setOcrLanguage(OcrLanguageMode value) async {
    if (_ocrLanguage == value) return;
    _ocrLanguage = value;
    notifyListeners();
    await _storage.setString(_ocrLanguageKey, value.name);
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope is missing above this context.');
    return scope!.notifier!;
  }
}
