import 'package:ai_question_bank_android/core/widgets/ambient_motion_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required bool reduceMotion}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 240,
        child: AmbientMotionLayer(reduceMotion: reduceMotion),
      ),
    ),
  );
}

void main() {
  testWidgets('ambient layer renders a static composition for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    await tester.pump();

    expect(find.byType(AmbientMotionLayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambient layer animates without intercepting input', (
    tester,
  ) async {
    await tester.pumpWidget(_host(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(IgnorePointer), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
