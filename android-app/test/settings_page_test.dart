import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_question_bank_android/app/app.dart';
import 'package:ai_question_bank_android/app/app_settings_controller.dart';
import 'package:ai_question_bank_android/core/theme/app_colors.dart';
import 'package:ai_question_bank_android/features/settings/settings_page.dart';

void main() {
  testWidgets('settings page follows dark theme and exposes preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {
      'settings.theme_v3': 'dark',
      'settings.locale_v3': 'zh',
    });
    final settings = await AppSettingsController.load();

    await tester.pumpWidget(
      AiQuestionBankApp(settings: settings, home: const SettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('偏好设置'), findsWidgets);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('界面语言'), findsOneWidget);
    expect(find.text('题目生成语言'), findsOneWidget);
    expect(find.text('OCR 识别语言'), findsOneWidget);
    expect(find.text('声音与震动'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, isNull);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      AppColors.darkBackground,
    );
  });
}
