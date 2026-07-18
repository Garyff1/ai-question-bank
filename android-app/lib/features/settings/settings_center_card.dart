import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_settings_controller.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/app_spacing.dart';
import 'third_party_notices_page.dart';
import '../official_ai/official_ai_page.dart';

class SettingsCenterCard extends StatelessWidget {
  const SettingsCenterCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.settingsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _label(context, l10n.appearance),
            const SizedBox(height: 8),
            DropdownButtonFormField<AppThemePreference>(
              initialValue: settings.themePreference,
              items: [
                DropdownMenuItem(
                  value: AppThemePreference.system,
                  child: _option(
                    Icons.brightness_auto_rounded,
                    l10n.followSystem,
                  ),
                ),
                DropdownMenuItem(
                  value: AppThemePreference.light,
                  child: _option(Icons.light_mode_rounded, l10n.lightMode),
                ),
                DropdownMenuItem(
                  value: AppThemePreference.dark,
                  child: _option(Icons.dark_mode_rounded, l10n.darkMode),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _feedback(settings);
                settings.setThemePreference(value);
              },
            ),
            const SizedBox(height: 18),
            _label(context, l10n.language),
            const SizedBox(height: 8),
            DropdownButtonFormField<AppLocalePreference>(
              initialValue: settings.localePreference,
              items: [
                DropdownMenuItem(
                  value: AppLocalePreference.system,
                  child: Text(l10n.followSystem),
                ),
                DropdownMenuItem(
                  value: AppLocalePreference.zh,
                  child: Text(l10n.simplifiedChinese),
                ),
                DropdownMenuItem(
                  value: AppLocalePreference.en,
                  child: Text(l10n.english),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _feedback(settings);
                settings.setLocalePreference(value);
              },
            ),
            const SizedBox(height: 14),
            _label(context, l10n.generationLanguage),
            const SizedBox(height: 8),
            DropdownButtonFormField<GenerationLanguage>(
              initialValue: settings.generationLanguage,
              items: [
                DropdownMenuItem(
                  value: GenerationLanguage.followMaterial,
                  child: Text(l10n.followMaterial),
                ),
                DropdownMenuItem(
                  value: GenerationLanguage.zh,
                  child: Text(l10n.simplifiedChinese),
                ),
                DropdownMenuItem(
                  value: GenerationLanguage.en,
                  child: Text(l10n.english),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _feedback(settings);
                settings.setGenerationLanguage(value);
              },
            ),
            const SizedBox(height: 14),
            _label(context, l10n.ocrLanguage),
            const SizedBox(height: 8),
            DropdownButtonFormField<OcrLanguageMode>(
              initialValue: settings.ocrLanguage,
              items: [
                DropdownMenuItem(
                  value: OcrLanguageMode.auto,
                  child: Text(l10n.ocrAuto),
                ),
                DropdownMenuItem(
                  value: OcrLanguageMode.chinese,
                  child: Text(l10n.ocrChinese),
                ),
                DropdownMenuItem(
                  value: OcrLanguageMode.english,
                  child: Text(l10n.ocrEnglish),
                ),
                DropdownMenuItem(
                  value: OcrLanguageMode.mixed,
                  child: Text(l10n.ocrMixed),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _feedback(settings);
                settings.setOcrLanguage(value);
              },
            ),
            const SizedBox(height: 18),
            _label(context, l10n.soundAndHaptics),
            _switch(
              context,
              title: l10n.soundEffects,
              value: settings.soundEnabled,
              icon: Icons.volume_up_rounded,
              onChanged: (value) {
                settings.setSoundEnabled(value);
                _feedback(settings);
              },
            ),
            _switch(
              context,
              title: l10n.backgroundSound,
              value: settings.backgroundSoundEnabled,
              icon: Icons.music_note_rounded,
              onChanged: (value) {
                settings.setBackgroundSoundEnabled(value);
                _feedback(settings);
              },
            ),
            _switch(
              context,
              title: l10n.hapticFeedback,
              value: settings.hapticsEnabled,
              icon: Icons.vibration_rounded,
              onChanged: (value) {
                settings.setHapticsEnabled(value);
                if (value) HapticFeedback.selectionClick();
              },
            ),
            _switch(
              context,
              title: l10n.reduceMotion,
              value: settings.reduceMotion,
              icon: Icons.motion_photos_off_rounded,
              onChanged: (value) {
                settings.setReduceMotion(value);
                _feedback(settings);
              },
            ),
            const Divider(height: 30),
            _label(context, l10n.aiService),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.key_rounded),
              title: Text(l10n.ownApiKey),
              trailing: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined),
              title: Text(
                Localizations.localeOf(context).languageCode == 'en'
                    ? 'Official AI service (testing)'
                    : '官方 AI 服务（测试中）',
              ),
              subtitle: Text(
                Localizations.localeOf(context).languageCode == 'en'
                    ? 'Mock payment only. No real charge.'
                    : '仅开放模拟支付，不会真实扣款',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const OfficialAiPage()),
              ),
            ),
            const Divider(height: 30),
            _label(context, l10n.dataAndPrivacy),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.policy_outlined),
              title: Text(l10n.openSourceLicenses),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ThirdPartyNoticesPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String value) {
    return Text(value, style: Theme.of(context).textTheme.labelLarge);
  }

  Widget _option(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _switch(
    BuildContext context, {
    required String title,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  void _feedback(AppSettingsController settings) {
    if (settings.hapticsEnabled) HapticFeedback.selectionClick();
  }
}
