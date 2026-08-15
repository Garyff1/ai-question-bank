import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'card_run_engine.dart';
import 'card_run_models.dart';

class CardRunPage extends StatefulWidget {
  const CardRunPage({
    super.key,
    required this.questions,
    required this.onExit,
    required this.onComplete,
    this.reduceMotion = false,
    this.hapticsEnabled = true,
  });

  final List<CardRunQuestion> questions;
  final VoidCallback onExit;
  final ValueChanged<CardRunResult> onComplete;
  final bool reduceMotion;
  final bool hapticsEnabled;

  @override
  State<CardRunPage> createState() => _CardRunPageState();
}

class _CardRunPageState extends State<CardRunPage> {
  late final CardRunEngine _engine;
  late List<CardDefinition> _choices;
  CardDefinition? _revealedCard;
  CardRunSubmitResult? _lastOutcome;
  CardRunQuestion? _outcomeQuestion;
  String? _selectedAnswer;
  bool _settled = false;

  bool get _english => Localizations.localeOf(context).languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _engine = CardRunEngine(questions: widget.questions);
    _choices = _engine.drawChoices();
  }

  void _haptic() {
    if (widget.hapticsEnabled) HapticFeedback.selectionClick();
  }

  void _selectCard(CardDefinition card) {
    if (_revealedCard != null) return;
    _haptic();
    setState(() => _revealedCard = card);
    _engine.selectCard(card);
    if (widget.reduceMotion) {
      setState(() => _revealedCard = null);
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 620), () {
      if (!mounted) return;
      setState(() => _revealedCard = null);
    });
  }

  void _reroll() {
    final next = _engine.rerollChoices();
    if (next.isEmpty) return;
    _haptic();
    setState(() => _choices = next);
  }

  void _submit(String answer) {
    if (_lastOutcome != null) return;
    _haptic();
    final answeredQuestion = _engine.currentQuestion;
    final outcome = _engine.submitAnswer(answer);
    if (outcome.requiresRetry) {
      setState(() {
        _selectedAnswer = null;
        _lastOutcome = null;
        _outcomeQuestion = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _english
                ? 'First answer recorded. Try this question once more.'
                : '首次错误已记录，再试一次。',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _selectedAnswer = answer;
      _lastOutcome = outcome;
      _outcomeQuestion = answeredQuestion;
    });
  }

  void _next() {
    if (_lastOutcome == null) return;
    setState(() {
      _lastOutcome = null;
      _outcomeQuestion = null;
      _selectedAnswer = null;
      if (_engine.needsCardChoice) _choices = _engine.drawChoices();
    });
  }

  void _finish() {
    if (_settled) return;
    _settled = true;
    widget.onComplete(_engine.buildResult());
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_english ? 'Leave Card Run?' : '退出 Card Run？'),
        content: Text(
          _english
              ? 'This run has not settled XP yet.'
              : '本局尚未结算 XP，退出后本局进度不会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_english ? 'Continue' : '继续学习'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_english ? 'Leave' : '退出本局'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _english ? 'Leave' : '退出本局',
            onPressed: _confirmExit,
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(_english ? 'Card Run' : '知识卡牌行程'),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text(
                  '${_engine.currentIndex}/${_engine.total}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: widget.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 320),
            child: _engine.isFinished && _lastOutcome == null
                ? _buildResult()
                : _engine.needsCardChoice || _revealedCard != null
                ? _buildCardChoice()
                : _buildQuestion(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardChoice() {
    final colors = Theme.of(context).colorScheme;
    final revealed = _revealedCard;
    return ListView(
      key: const ValueKey('card-choice'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Text(
          _english ? 'Choose your next knowledge card' : '选择下一张知识卡',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          _english
              ? 'Cards only change this run. They never call AI automatically.'
              : '卡牌只影响本局学习，不会自动调用 AI。',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (revealed != null)
          Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              scale: 1.04,
              child: SizedBox(
                width: 260,
                child: _KnowledgeCard(
                  card: revealed,
                  selected: true,
                  onTap: () {},
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 650;
              if (narrow) {
                return Column(
                  children: [
                    for (final card in _choices) ...[
                      _KnowledgeCard(
                        key: ValueKey('card-${card.id}'),
                        card: card,
                        onTap: () => _selectCard(card),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final card in _choices)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _KnowledgeCard(
                          key: ValueKey('card-${card.id}'),
                          card: card,
                          onTap: () => _selectCard(card),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        if (revealed == null && _engine.canReroll) ...[
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton.icon(
              onPressed: _reroll,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_english ? 'Reroll once' : '重抽一次'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuestion() {
    final colors = Theme.of(context).colorScheme;
    final outcome = _lastOutcome;
    final question = outcome == null
        ? _engine.currentQuestion!
        : (_outcomeQuestion ?? _engine.answers.last.question);
    final displayIndex = outcome == null
        ? _engine.currentIndex + 1
        : _engine.currentIndex;
    return ListView(
      key: ValueKey('question-${question.id}-${_engine.currentIndex}'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: _engine.currentIndex / _engine.total,
            minHeight: 9,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 12),
        if (_engine.activeEffectLabels.isNotEmpty)
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final label in _engine.activeEffectLabels)
                Chip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.knowledgePoint,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$displayIndex/${_engine.total}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                question.prompt,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 19,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (question.options.length >= 2)
          for (final option in question.options) ...[
            _AnswerTile(
              option: option,
              selected: _selectedAnswer == option,
              disabled: outcome != null,
              onTap: () => _submit(option),
            ),
            const SizedBox(height: 10),
          ]
        else ...[
          OutlinedButton.icon(
            onPressed: outcome == null ? () => _submit('还需复习') : null,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_english ? 'Review again' : '还需复习'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: outcome == null ? () => _submit(question.answer) : null,
            icon: const Icon(Icons.check_rounded),
            label: Text(_english ? 'I remember' : '我记住了'),
          ),
        ],
        if (outcome != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: outcome.correct
                  ? colors.primaryContainer
                  : outcome.corrected
                  ? colors.tertiaryContainer
                  : colors.errorContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outcome.correct
                      ? (_english ? 'Correct' : '回答正确')
                      : outcome.corrected
                      ? (_english ? 'Corrected on retry' : '已在重试中订正')
                      : outcome.shieldUsed
                      ? (_english
                            ? 'Shield used; mistake recorded'
                            : '护盾已生效，错题仍如实记录')
                      : (_english ? 'Keep learning' : '继续巩固'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (question.explanation.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(question.explanation),
                ],
                const SizedBox(height: 7),
                Text(
                  '+${outcome.baseXp} XP · ${_english ? 'Card bonus' : '卡牌加成'} +${outcome.bonusXp}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _next,
            child: Text(
              _engine.isFinished
                  ? (_english ? 'View result' : '查看结算')
                  : (_english ? 'Continue' : '继续'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult() {
    final colors = Theme.of(context).colorScheme;
    final result = _engine.buildResult();
    return ListView(
      key: const ValueKey('card-run-result'),
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.workspace_premium_rounded, size: 74, color: colors.primary),
        const SizedBox(height: 14),
        Text(
          _english ? 'Run complete' : '本局学习完成',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '${result.correct}/${result.total} ${_english ? 'correct' : '正确'} · ${result.corrected} ${_english ? 'corrected' : '道已订正'}',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _ResultMetric(
                label: _english ? 'Base XP' : '基础 XP',
                value: '${result.baseXp}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ResultMetric(
                label: _english ? 'Card bonus' : '卡牌加成',
                value: '+${result.cardBonusXp + result.eventBonusXp}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ResultMetric(
          label: _english ? 'Total earned' : '本局获得',
          value: '${result.totalXp} XP',
          emphasized: true,
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final card in result.selectedCards)
              Chip(label: Text(card.title)),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('settle-card-run'),
          onPressed: _finish,
          icon: const Icon(Icons.check_circle_rounded),
          label: Text(_english ? 'Settle and return' : '结算并返回'),
        ),
      ],
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({
    super.key,
    required this.card,
    required this.onTap,
    this.selected = false,
  });

  final CardDefinition card;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(card.type);
    return Semantics(
      button: true,
      label: '${card.title}：${card.description}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            constraints: const BoxConstraints(minHeight: 190),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? .82 : .28),
                width: selected ? 2.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.first.withValues(alpha: .28),
                  blurRadius: selected ? 28 : 16,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon(card.type), color: Colors.white),
                    const Spacer(),
                    Text(
                      _rarity(card.rarity),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  card.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  card.description,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Color> _palette(CardRunCardType type) => switch (type) {
    CardRunCardType.review => const [Color(0xFF334155), Color(0xFF2563EB)],
    CardRunCardType.boost => const [Color(0xFF0F766E), Color(0xFF22C55E)],
    CardRunCardType.challenge => const [Color(0xFF9A3412), Color(0xFFEF4444)],
    CardRunCardType.support => const [Color(0xFF1D4ED8), Color(0xFF06B6D4)],
    CardRunCardType.event => const [Color(0xFF6D28D9), Color(0xFFDB2777)],
  };

  static IconData _icon(CardRunCardType type) => switch (type) {
    CardRunCardType.review => Icons.history_edu_rounded,
    CardRunCardType.boost => Icons.bolt_rounded,
    CardRunCardType.challenge => Icons.local_fire_department_rounded,
    CardRunCardType.support => Icons.shield_rounded,
    CardRunCardType.event => Icons.auto_awesome_rounded,
  };

  static String _rarity(CardRunRarity rarity) => switch (rarity) {
    CardRunRarity.common => '普通',
    CardRunRarity.uncommon => '少见',
    CardRunRarity.rare => '稀有',
    CardRunRarity.special => '特殊',
  };
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.option,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Text(
            option,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: emphasized
            ? colors.primaryContainer
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: emphasized ? colors.onPrimaryContainer : colors.onSurface,
              fontSize: emphasized ? 28 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
