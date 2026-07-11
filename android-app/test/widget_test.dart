import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_question_bank_android/main.dart';

void main() {
  testWidgets('AI question bank app starts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_seen_v1': true,
    });
    await tester.pumpWidget(const AiQuestionBankApp());
    // 启动页包含持续动画，不能使用 pumpAndSettle 等待动画彻底停止。
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('今天也来巩固一点知识吧'), findsOneWidget);
    expect(find.text('今日学习状态'), findsOneWidget);
  });
}
