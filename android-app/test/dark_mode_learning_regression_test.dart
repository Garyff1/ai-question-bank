import 'package:ai_question_bank_android/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('challenge prompt uses the active dark-theme foreground', (
    tester,
  ) async {
    const prompt = '将机器人上电步骤排列为正确顺序';
    final session = MiniGameSession(
      materialName: '机器人学导论',
      games: const [
        MiniGame(
          type: MiniGameType.reorder,
          prompt: prompt,
          options: ['检查急停', '接通电源', '启动控制器'],
          answer: '0,1,2',
          knowledgePoint: '机器人启动流程',
        ),
      ],
      subject: '通用',
      chapter: 1,
      level: 1,
      isBoss: false,
      startTime: DateTime(2026, 8, 8),
      lives: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MiniGamePage(session: session, onExit: () {}, onComplete: (_) {}),
      ),
    );

    final promptFinder = find.text(prompt);
    expect(promptFinder, findsOneWidget);
    final promptText = tester.widget<Text>(promptFinder);
    final colors = Theme.of(tester.element(promptFinder)).colorScheme;
    expect(promptText.style?.color, colors.onSurface);
  });

  testWidgets('practice detail keeps type labels readable and concise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = PracticeRecord(
      materialName: '机器人学导论',
      total: 2,
      correct: 1,
      createdAt: DateTime(2026, 8, 8),
      questionStats: const [
        QuestionStat(
          type: 'choice',
          isCorrect: false,
          answerLetter: 'B',
          knowledgePoint: '关节驱动',
          questionText: '负载变化会怎样影响机器人关节电机电流？',
        ),
        QuestionStat(
          type: 'choice',
          isCorrect: true,
          answerLetter: 'A',
          knowledgePoint: '坐标变换',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PracticeHistoryDetailPage(record: record),
      ),
    );
    await tester.pumpAndSettle();

    final summaryTitle = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data == 'Mistake priorities' || widget.data == '本次错题核心知识点'),
    );
    expect(summaryTitle, findsOneWidget);
    expect(find.text('Weakest'), findsNothing);
    expect(find.text('掌握最弱'), findsNothing);
    final typeFinder = find.text('单选');
    expect(typeFinder, findsOneWidget);
    final typeText = tester.widget<Text>(typeFinder);
    final colors = Theme.of(tester.element(typeFinder)).colorScheme;
    expect(typeText.style?.color, colors.onSurface);
  });
}
