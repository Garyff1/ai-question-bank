import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_question_bank_android/app/app_settings_controller.dart';

void main() {
  test('v3 settings load defaults without touching legacy data', () async {
    SharedPreferences.setMockInitialValues({
      'materials_v1': 'legacy-materials',
      'rpg_progress_v1': 'legacy-rpg',
    });

    final settings = await AppSettingsController.load();

    expect(settings.themePreference, AppThemePreference.system);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.locale, isNull);
    expect(settings.soundEnabled, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('materials_v1'), 'legacy-materials');
    expect(preferences.getString('rpg_progress_v1'), 'legacy-rpg');
  });

  test('theme language and motion preferences persist', () async {
    SharedPreferences.setMockInitialValues(const {});
    final settings = await AppSettingsController.load();

    await settings.setThemePreference(AppThemePreference.dark);
    await settings.setLocalePreference(AppLocalePreference.en);
    await settings.setGenerationLanguage(GenerationLanguage.en);
    await settings.setReduceMotion(true);

    final restored = await AppSettingsController.load();
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.locale, const Locale('en'));
    expect(restored.generationLanguage, GenerationLanguage.en);
    expect(restored.reduceMotion, isTrue);
  });
}
