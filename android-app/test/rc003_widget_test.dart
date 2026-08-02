import 'package:ai_question_bank_android/features/paper_builder/models/paper_builder_models.dart';
import 'package:ai_question_bank_android/features/paper_builder/paper_editor_page.dart';
import 'package:ai_question_bank_android/features/service_mode/service_mode_controller.dart';
import 'package:ai_question_bank_android/features/service_mode/service_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('service mode card exposes direct switch affordance', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CurrentServiceModeCard(
            mode: AiServiceMode.byok,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('使用自己的 API Key'), findsOneWidget);
    expect(find.text('切换'), findsOneWidget);
    await tester.tap(find.text('切换'));
    expect(tapped, isTrue);
  });

  testWidgets('paper editor exposes both previews and single-question tools', (
    tester,
  ) async {
    var started = false;
    final document = PaperEditorDocument(
      id: 'paper',
      name: '内部测试卷',
      durationMinutes: 45,
      totalScore: 10,
      materialName: '测试资料',
      questions: const [
        PaperEditorQuestion(
          id: 'q1',
          type: 'choice',
          prompt: '请选择正确答案',
          options: ['A', 'B'],
          answer: 'A',
          explanation: '测试解析',
          knowledgePoint: '测试知识点',
          score: 10,
          section: '选择题',
        ),
      ],
      updatedAt: DateTime(2026, 8, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PaperEditorPage(
          document: document,
          onPreview: (_, _) async {},
          onRegenerate: (question, _) async => question,
          onStartPractice: (_) async => started = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('编辑试卷'), findsOneWidget);
    expect(find.text('学生版预览'), findsOneWidget);
    expect(find.text('教师版预览'), findsOneWidget);
    expect(find.byTooltip('只重新生成本题'), findsOneWidget);
    expect(find.text('开始答题'), findsOneWidget);
    await tester.tap(find.text('开始答题'));
    await tester.pump();
    expect(started, isTrue);
  });
}
