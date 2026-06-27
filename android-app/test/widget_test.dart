import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_question_bank_android/main.dart';

void main() {
  testWidgets('AI question bank app starts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AiQuestionBankApp());
    await tester.pumpAndSettle();

    expect(find.text('AI题库'), findsWidgets);
    expect(find.text('安卓单体版 · 无登录 · 不需要外部后端'), findsOneWidget);
  });
}
