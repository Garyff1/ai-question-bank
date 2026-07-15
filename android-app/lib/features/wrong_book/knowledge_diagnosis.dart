import 'package:flutter/material.dart';

enum KnowledgeMastery { needsWork, improving, mastered }

enum KnowledgeDiagnosisSort { weakest, mostWrong, recent }

class KnowledgeAttempt {
  const KnowledgeAttempt({
    required this.knowledgePoint,
    required this.isCorrect,
    required this.occurredAt,
    this.question = '',
    this.explanation = '',
  });

  final String knowledgePoint;
  final bool isCorrect;
  final DateTime occurredAt;
  final String question;
  final String explanation;
}

class KnowledgeDiagnosis {
  const KnowledgeDiagnosis({
    required this.name,
    required this.total,
    required this.wrong,
    required this.lastWrongAt,
    required this.consecutiveCorrect,
    required this.wrongQuestions,
    required this.explanations,
  });

  final String name;
  final int total;
  final int wrong;
  final DateTime? lastWrongAt;
  final int consecutiveCorrect;
  final List<String> wrongQuestions;
  final List<String> explanations;

  int get accuracy => total == 0 ? 0 : ((total - wrong) / total * 100).round();

  KnowledgeMastery get mastery {
    if (consecutiveCorrect >= 4 && accuracy >= 70) {
      return KnowledgeMastery.mastered;
    }
    if (consecutiveCorrect >= 2 || accuracy >= 50) {
      return KnowledgeMastery.improving;
    }
    return KnowledgeMastery.needsWork;
  }
}

List<KnowledgeDiagnosis> buildKnowledgeDiagnoses(
  Iterable<KnowledgeAttempt> attempts,
) {
  final grouped = <String, List<KnowledgeAttempt>>{};
  for (final attempt in attempts) {
    final key = attempt.knowledgePoint.trim().isEmpty
        ? '综合'
        : attempt.knowledgePoint.trim();
    grouped.putIfAbsent(key, () => []).add(attempt);
  }
  final result = <KnowledgeDiagnosis>[];
  for (final entry in grouped.entries) {
    final values = entry.value
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final wrongValues = values.where((value) => !value.isCorrect).toList();
    if (wrongValues.isEmpty) continue;
    var streak = 0;
    for (final value in values.reversed) {
      if (!value.isCorrect) break;
      streak++;
    }
    result.add(
      KnowledgeDiagnosis(
        name: entry.key,
        total: values.length,
        wrong: wrongValues.length,
        lastWrongAt: wrongValues.last.occurredAt,
        consecutiveCorrect: streak,
        wrongQuestions: wrongValues
            .map((value) => value.question.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        explanations: wrongValues
            .map((value) => value.explanation.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false),
      ),
    );
  }
  return result;
}

class KnowledgeDiagnosisList extends StatefulWidget {
  const KnowledgeDiagnosisList({
    super.key,
    required this.items,
    this.onReinforce,
  });

  final List<KnowledgeDiagnosis> items;
  final ValueChanged<KnowledgeDiagnosis>? onReinforce;

  @override
  State<KnowledgeDiagnosisList> createState() => _KnowledgeDiagnosisListState();
}

class _KnowledgeDiagnosisListState extends State<KnowledgeDiagnosisList> {
  KnowledgeDiagnosisSort _sort = KnowledgeDiagnosisSort.weakest;

  bool get _english => Localizations.localeOf(context).languageCode == 'en';
  String _t(String zh, String en) => _english ? en : zh;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            _t('本次练习没有错题，继续保持！', 'No mistakes in this session. Keep it up!'),
          ),
        ),
      );
    }
    final items = [...widget.items];
    switch (_sort) {
      case KnowledgeDiagnosisSort.weakest:
        items.sort((a, b) {
          final mastery = a.mastery.index.compareTo(b.mastery.index);
          return mastery != 0 ? mastery : a.accuracy.compareTo(b.accuracy);
        });
      case KnowledgeDiagnosisSort.mostWrong:
        items.sort((a, b) => b.wrong.compareTo(a.wrong));
      case KnowledgeDiagnosisSort.recent:
        items.sort(
          (a, b) => (b.lastWrongAt ?? DateTime(1970)).compareTo(
            a.lastWrongAt ?? DateTime(1970),
          ),
        );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<KnowledgeDiagnosisSort>(
            segments: [
              ButtonSegment(
                value: KnowledgeDiagnosisSort.weakest,
                label: Text(_t('掌握最弱', 'Weakest')),
              ),
              ButtonSegment(
                value: KnowledgeDiagnosisSort.mostWrong,
                label: Text(_t('错题最多', 'Most mistakes')),
              ),
              ButtonSegment(
                value: KnowledgeDiagnosisSort.recent,
                label: Text(_t('最近出错', 'Most recent')),
              ),
            ],
            selected: {_sort},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _sort = value.first),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _card(context, item)),
      ],
    );
  }

  Widget _card(BuildContext context, KnowledgeDiagnosis item) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (item.mastery) {
      KnowledgeMastery.needsWork => (_t('需要巩固', 'Needs work'), colors.error),
      KnowledgeMastery.improving => (
        _t('正在进步', 'Improving'),
        const Color(0xFFF59E0B),
      ),
      KnowledgeMastery.mastered => (
        _t('基本掌握', 'Mostly mastered'),
        const Color(0xFF10B981),
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _metric(_t('错题', 'Wrong'), '${item.wrong}'),
              _metric(_t('正确率', 'Accuracy'), '${item.accuracy}%'),
              _metric(
                _t('连续答对', 'Correct streak'),
                '${item.consecutiveCorrect}',
              ),
              _metric(_t('最近出错', 'Last mistake'), _date(item.lastWrongAt)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => widget.onReinforce?.call(item),
                icon: const Icon(Icons.fitness_center_rounded, size: 18),
                label: Text(_t('开始巩固', 'Reinforce')),
              ),
              OutlinedButton(
                onPressed: () => _showItems(
                  _t('相关错题', 'Related mistakes'),
                  item.wrongQuestions,
                  _t(
                    '旧记录未保存题干，请到错题本查看。',
                    'This older record did not save question text. Open the mistake book instead.',
                  ),
                ),
                child: Text(_t('查看错题', 'Mistakes')),
              ),
              OutlinedButton(
                onPressed: () => _showItems(
                  _t('相关解析', 'Explanations'),
                  item.explanations,
                  _t(
                    '旧记录未保存解析，请到错题本查看。',
                    'This older record did not save explanations. Open the mistake book instead.',
                  ),
                ),
                child: Text(_t('查看解析', 'Explanations')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Text(
    '$label $value',
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
  );

  String _date(DateTime? value) {
    if (value == null) return '--';
    return '${value.month}/${value.day}';
  }

  Future<void> _showItems(String title, List<String> values, String empty) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: values.isEmpty
              ? Text(empty)
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: values.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) =>
                      Text('${index + 1}. ${values[index]}'),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('关闭', 'Close')),
          ),
        ],
      ),
    );
  }
}
