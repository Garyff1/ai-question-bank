import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_question_bank_android/features/card_run/card_run_engine.dart';
import 'package:ai_question_bank_android/features/card_run/card_run_models.dart';
import 'package:ai_question_bank_android/features/card_run/card_run_page.dart';

CardDefinition _card(String id) =>
    cardRunDeck.singleWhere((item) => item.id == id);

List<CardRunQuestion> _questions({int count = 10, bool wrong = false}) => [
  for (var index = 0; index < count; index++)
    CardRunQuestion(
      id: 'q-$index',
      prompt: '第 ${index + 1} 题',
      options: const ['A. 正确', 'B. 错误'],
      answer: 'A',
      explanation: '解析 $index',
      knowledgePoint: index.isEven ? '知识点一' : '知识点二',
      isWrong: wrong || index == 0,
    ),
];

void main() {
  group('Card Run rules', () {
    test('deck contains 15 cards across all five card types', () {
      expect(cardRunDeck, hasLength(15));
      expect(
        cardRunDeck.map((item) => item.type).toSet(),
        CardRunCardType.values.toSet(),
      );
    });

    test('draws three cards and excludes review cards without wrongs', () {
      final questions = _questions().map((item) {
        return CardRunQuestion(
          id: item.id,
          prompt: item.prompt,
          options: item.options,
          answer: item.answer,
          knowledgePoint: item.knowledgePoint,
        );
      }).toList();
      final engine = CardRunEngine(questions: questions, random: Random(7));

      final choices = engine.drawChoices();

      expect(choices, hasLength(3));
      expect(
        choices.every((item) => item.type != CardRunCardType.review),
        isTrue,
      );
    });

    test('double growth adds but never multiplies beyond base XP', () {
      final engine = CardRunEngine(questions: _questions(count: 1));
      engine.selectCard(_card('boost_double_growth'));

      final outcome = engine.submitAnswer('A. 正确');
      final result = engine.buildResult();

      expect(outcome.baseXp, 10);
      expect(outcome.bonusXp, 10);
      expect(result.totalXp, 20);
    });

    test('shield protects the run streak but preserves the real mistake', () {
      final engine = CardRunEngine(questions: _questions(count: 1));
      engine.selectCard(_card('support_shield'));

      final outcome = engine.submitAnswer('B. 错误');
      final result = engine.buildResult();

      expect(outcome.shieldUsed, isTrue);
      expect(result.answers.single.correct, isFalse);
      expect(result.correct, 0);
    });

    test('retry keeps the first error and marks a later correction', () {
      final engine = CardRunEngine(questions: _questions(count: 1));
      engine.selectCard(_card('support_retry'));

      final first = engine.submitAnswer('B. 错误');
      final second = engine.submitAnswer('A. 正确');
      final result = engine.buildResult();

      expect(first.requiresRetry, isTrue);
      expect(second.correct, isFalse);
      expect(second.corrected, isTrue);
      expect(result.answers.single.correct, isFalse);
      expect(result.answers.single.corrected, isTrue);
    });

    test('card choices appear at the start and after questions 3 and 6', () {
      final engine = CardRunEngine(questions: _questions(), random: Random(2));
      expect(engine.needsCardChoice, isTrue);

      engine.selectCard(_card('event_chest'));
      for (var index = 0; index < 3; index++) {
        engine.submitAnswer('A');
      }
      expect(engine.needsCardChoice, isTrue);

      engine.selectCard(_card('support_shield'));
      for (var index = 0; index < 3; index++) {
        engine.submitAnswer('A');
      }
      expect(engine.needsCardChoice, isTrue);
    });
  });

  testWidgets('Card Run completes locally and settles exactly once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var settlementCount = 0;
    CardRunResult? settlement;
    await tester.pumpWidget(
      MaterialApp(
        home: CardRunPage(
          questions: _questions(count: 3),
          reduceMotion: true,
          hapticsEnabled: false,
          onExit: () {},
          onComplete: (result) {
            settlementCount++;
            settlement = result;
          },
        ),
      ),
    );

    final availableCard = cardRunDeck.firstWhere(
      (card) => find.byKey(ValueKey('card-${card.id}')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(ValueKey('card-${availableCard.id}')));
    await tester.pump();

    for (var index = 0; index < 3; index++) {
      expect(find.text('第 ${index + 1} 题'), findsOneWidget);
      await tester.tap(find.text('A. 正确'));
      await tester.pump();
      if (index < 2) {
        await tester.tap(find.text('Continue'));
      } else {
        await tester.tap(find.text('View result'));
      }
      await tester.pump();
    }

    expect(find.byKey(const ValueKey('card-run-result')), findsOneWidget);
    final settleButton = find.byKey(const ValueKey('settle-card-run'));
    await tester.ensureVisible(settleButton);
    await tester.tap(settleButton);
    await tester.pump();
    tester.widget<FilledButton>(settleButton).onPressed?.call();

    expect(settlementCount, 1);
    expect(settlement?.total, 3);
    expect(settlement?.correct, 3);
  });
}
