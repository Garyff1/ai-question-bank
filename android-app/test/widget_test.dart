import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_question_bank_android/app/app.dart';
import 'package:ai_question_bank_android/app/app_settings_controller.dart';

void main() {
  testWidgets('AI question bank app starts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final settings = await AppSettingsController.load();
    await tester.pumpWidget(
      AiQuestionBankApp(
        settings: settings,
        home: const Scaffold(body: Center(child: Text('app-ready'))),
      ),
    );

    expect(find.text('app-ready'), findsOneWidget);
  });
}
