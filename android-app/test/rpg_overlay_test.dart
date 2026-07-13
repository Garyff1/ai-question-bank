import 'package:ai_question_bank_android/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _result = RpgLevelResult(
  chapter: 1,
  level: 1,
  stars: 2,
  earnedXp: 17,
  newBadges: [],
  chapterCleared: false,
  allCleared: false,
);

void main() {
  testWidgets('RPG result next button closes the dialog', (tester) async {
    RpgCompletionAction? selectedAction;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (pageContext) => FilledButton(
            onPressed: () async {
              selectedAction = await showDialog<RpgCompletionAction>(
                context: pageContext,
                barrierDismissible: false,
                builder: (_) => const RpgLevelCompleteOverlay(result: _result),
              );
            },
            child: const Text('打开结算'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开结算'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('下一关'));
    await tester.pumpAndSettle();

    expect(selectedAction, RpgCompletionAction.next);
    expect(find.text('下一关'), findsNothing);
  });

  testWidgets('RPG result back button closes the dialog', (tester) async {
    RpgCompletionAction? selectedAction;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (pageContext) => FilledButton(
            onPressed: () async {
              selectedAction = await showDialog<RpgCompletionAction>(
                context: pageContext,
                barrierDismissible: false,
                builder: (_) => const RpgLevelCompleteOverlay(result: _result),
              );
            },
            child: const Text('打开结算'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开结算'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('返回地图'));
    await tester.pumpAndSettle();

    expect(selectedAction, RpgCompletionAction.backToMap);
    expect(find.text('返回地图'), findsNothing);
  });
}
