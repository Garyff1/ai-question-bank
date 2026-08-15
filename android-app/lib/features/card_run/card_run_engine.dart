import 'dart:math';

import 'card_run_models.dart';

class CardRunEngine {
  CardRunEngine({required List<CardRunQuestion> questions, Random? random})
    : assert(questions.isNotEmpty),
      _questions = List<CardRunQuestion>.from(questions.take(10)),
      _random = random ?? Random();

  final List<CardRunQuestion> _questions;
  final Random _random;
  final List<CardRunAnswer> _answers = [];
  final List<CardDefinition> _selectedCards = [];
  final List<_ActiveEffect> _effects = [];

  bool _awaitingCardChoice = true;
  int _rerollCharges = 0;
  int _retryCharges = 0;
  int _shieldCharges = 0;
  int _eventBonusXp = 0;
  int _streak = 0;
  String? _pendingFirstAnswer;
  bool _retryingCurrent = false;

  List<CardRunQuestion> get questions => List.unmodifiable(_questions);
  List<CardRunAnswer> get answers => List.unmodifiable(_answers);
  List<CardDefinition> get selectedCards => List.unmodifiable(_selectedCards);
  CardRunQuestion? get currentQuestion => isFinished
      ? null
      : _questions[_answers.length.clamp(0, _questions.length - 1)];
  int get currentIndex => _answers.length;
  int get total => _questions.length;
  bool get isFinished => _answers.length >= _questions.length;
  bool get needsCardChoice => !isFinished && _awaitingCardChoice;
  bool get canReroll => _rerollCharges > 0 && needsCardChoice;
  int get eventBonusXp => _eventBonusXp;
  int get streak => _streak;
  bool get retryingCurrent => _retryingCurrent;

  List<String> get activeEffectLabels => [
    if (_shieldCharges > 0) '学习护盾 ×$_shieldCharges',
    if (_retryCharges > 0) '再试一次 ×$_retryCharges',
    if (_rerollCharges > 0) '重抽 ×$_rerollCharges',
    ..._effects.map((item) => '${item.card.title} · ${item.remaining}题'),
  ];

  List<CardDefinition> drawChoices() {
    if (!needsCardChoice) return const [];
    final selectedIds = _selectedCards.map((item) => item.id).toSet();
    var pool = cardRunDeck
        .where(
          (item) =>
              !selectedIds.contains(item.id) &&
              (_questions.any((question) => question.isWrong) ||
                  item.type != CardRunCardType.review),
        )
        .toList(growable: false);
    if (pool.length < 3) pool = List<CardDefinition>.from(cardRunDeck);

    final choices = <CardDefinition>[];
    final usedTypes = <CardRunCardType>{};
    while (choices.length < 3 && pool.isNotEmpty) {
      final weighted = <CardDefinition>[
        for (final card in pool)
          for (var index = 0; index < card.weight; index++) card,
      ];
      final preferred = weighted
          .where((card) => !usedTypes.contains(card.type))
          .toList(growable: false);
      final source = preferred.isEmpty ? weighted : preferred;
      final chosen = source[_random.nextInt(source.length)];
      choices.add(chosen);
      usedTypes.add(chosen.type);
      pool = pool.where((item) => item.id != chosen.id).toList(growable: false);
    }
    return choices;
  }

  List<CardDefinition> rerollChoices() {
    if (!canReroll) return const [];
    _rerollCharges--;
    return drawChoices();
  }

  void selectCard(CardDefinition card) {
    if (!needsCardChoice) return;
    _selectedCards.add(card);
    _awaitingCardChoice = false;
    switch (card.effect) {
      case 'prioritize_wrong':
        _moveNext((item) => item.isWrong);
        if (card.durationQuestions > 0) {
          _effects.add(_ActiveEffect(card));
        }
        break;
      case 'prioritize_weak':
        final weak = _mostCommonWrongKnowledgePoint();
        if (weak != null) {
          _moveNext((item) => item.knowledgePoint == weak);
        }
        if (card.durationQuestions > 0) {
          _effects.add(_ActiveEffect(card));
        }
        break;
      case 'shield':
        _shieldCharges += (card.parameters['charges'] ?? 1).toInt();
        break;
      case 'retry':
        _retryCharges += (card.parameters['charges'] ?? 1).toInt();
        break;
      case 'reroll':
        _rerollCharges += (card.parameters['charges'] ?? 1).toInt();
        break;
      case 'event_bonus':
        _eventBonusXp += (card.parameters['bonus'] ?? 0).toInt();
        break;
      case 'mystery':
        if (_random.nextBool()) {
          _eventBonusXp += 4;
        } else {
          _shieldCharges++;
        }
        break;
      default:
        if (card.durationQuestions > 0) {
          _effects.add(_ActiveEffect(card));
        }
        break;
    }
  }

  CardRunSubmitResult submitAnswer(String answer) {
    final question = currentQuestion;
    if (question == null || needsCardChoice) {
      throw StateError('Card Run 当前没有可作答题目');
    }
    final correct = _matches(answer, question.answer);

    if (_retryingCurrent) {
      final first = _pendingFirstAnswer ?? '';
      _retryingCurrent = false;
      _pendingFirstAnswer = null;
      final corrected = correct;
      final bonus = corrected ? 2 : 0;
      _answers.add(
        CardRunAnswer(
          question: question,
          userAnswer: '$first → $answer',
          correct: false,
          corrected: corrected,
          baseXp: 0,
          bonusXp: bonus,
        ),
      );
      _advanceEffects(correct: false);
      _afterQuestion(correct: false, shieldUsed: false);
      return CardRunSubmitResult(
        correct: false,
        corrected: corrected,
        requiresRetry: false,
        shieldUsed: false,
        baseXp: 0,
        bonusXp: bonus,
      );
    }

    if (!correct && _retryCharges > 0) {
      _retryCharges--;
      _pendingFirstAnswer = answer;
      _retryingCurrent = true;
      return const CardRunSubmitResult(
        correct: false,
        corrected: false,
        requiresRetry: true,
        shieldUsed: false,
        baseXp: 0,
        bonusXp: 0,
      );
    }

    final shieldUsed = !correct && _shieldCharges > 0;
    if (shieldUsed) _shieldCharges--;
    final baseXp = correct ? 10 : 0;
    final bonusXp = correct ? _questionBonus(baseXp) : 0;
    _answers.add(
      CardRunAnswer(
        question: question,
        userAnswer: answer,
        correct: correct,
        corrected: false,
        baseXp: baseXp,
        bonusXp: bonusXp,
      ),
    );
    _advanceEffects(correct: correct);
    _afterQuestion(correct: correct, shieldUsed: shieldUsed);
    return CardRunSubmitResult(
      correct: correct,
      corrected: false,
      requiresRetry: false,
      shieldUsed: shieldUsed,
      baseXp: baseXp,
      bonusXp: bonusXp,
    );
  }

  CardRunResult buildResult() {
    if (!isFinished) throw StateError('Card Run 尚未完成');
    return CardRunResult(
      answers: List.unmodifiable(_answers),
      selectedCards: List.unmodifiable(_selectedCards),
      eventBonusXp: _eventBonusXp,
    );
  }

  int _questionBonus(int baseXp) {
    var bonus = 0;
    for (final effect in _effects) {
      final card = effect.card;
      switch (card.effect) {
        case 'bonus_percent':
          bonus += (baseXp * (card.parameters['percent'] ?? 0) / 100).round();
          break;
        case 'bonus_fixed':
        case 'next_correct_bonus':
        case 'prioritize_wrong':
        case 'prioritize_weak':
          bonus += (card.parameters['bonus'] ?? 0).toInt();
          break;
        default:
          break;
      }
    }
    // 普通单题卡牌奖励不得超过基础 XP 的 100%。
    return bonus.clamp(0, baseXp);
  }

  void _advanceEffects({required bool correct}) {
    for (final effect in List<_ActiveEffect>.from(_effects)) {
      effect.attempted++;
      if (correct) {
        effect.correct++;
        effect.streak++;
        effect.maxStreak = max(effect.maxStreak, effect.streak);
      } else {
        effect.streak = 0;
      }
      effect.remaining--;
      if (effect.remaining <= 0) {
        _settleEffect(effect);
        _effects.remove(effect);
      }
    }
  }

  void _settleEffect(_ActiveEffect effect) {
    final card = effect.card;
    if (card.effect == 'accuracy_challenge') {
      final accuracy = effect.attempted == 0
          ? 0
          : (effect.correct * 100 / effect.attempted).round();
      if (accuracy >= (card.parameters['target'] ?? 80)) {
        _eventBonusXp += (card.parameters['bonus'] ?? 0).toInt();
      }
    } else if (card.effect == 'streak_challenge' &&
        effect.maxStreak >= (card.parameters['target'] ?? 3)) {
      _eventBonusXp += (card.parameters['bonus'] ?? 0).toInt();
    } else if (card.effect == 'boss_challenge' &&
        effect.correct >= (card.parameters['target'] ?? 3)) {
      _eventBonusXp += (card.parameters['bonus'] ?? 0).toInt();
    }
  }

  void _afterQuestion({required bool correct, required bool shieldUsed}) {
    if (correct) {
      _streak++;
    } else if (!shieldUsed) {
      _streak = 0;
    }
    if (!isFinished && (_answers.length == 3 || _answers.length == 6)) {
      _awaitingCardChoice = true;
    }
  }

  void _moveNext(bool Function(CardRunQuestion question) predicate) {
    final start = _answers.length;
    if (start >= _questions.length) return;
    final found = _questions.indexWhere(predicate, start);
    if (found <= start) return;
    final question = _questions.removeAt(found);
    _questions.insert(start, question);
  }

  String? _mostCommonWrongKnowledgePoint() {
    final counts = <String, int>{};
    for (final question in _questions.where((item) => item.isWrong)) {
      counts.update(
        question.knowledgePoint,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  bool _matches(String user, String answer) {
    String normalize(String value) {
      final text = value.trim();
      final letter = RegExp(r'^([A-Da-d])(?:[.、)\s]|$)').firstMatch(text);
      return (letter?.group(1) ?? text).toUpperCase().replaceAll(
        RegExp(r'\s+'),
        '',
      );
    }

    return normalize(user) == normalize(answer);
  }
}

class _ActiveEffect {
  _ActiveEffect(this.card) : remaining = card.durationQuestions;

  final CardDefinition card;
  int remaining;
  int attempted = 0;
  int correct = 0;
  int streak = 0;
  int maxStreak = 0;
}
