import 'package:flutter/material.dart';

class PaperGenerationProgress extends StatelessWidget {
  const PaperGenerationProgress({
    super.key,
    required this.stage,
    this.currentQuestion,
    this.totalQuestions,
    this.onCancel,
  });
  final int stage;
  final int? currentQuestion;
  final int? totalQuestions;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final zhStages = ['正在分析资料', '正在规划题型', '正在生成题目', '正在生成答案和解析', '正在整理试卷'];
    final enStages = [
      'Analyzing materials',
      'Planning question types',
      'Generating questions',
      'Generating answers and explanations',
      'Finalizing paper',
    ];
    final safeStage = stage.clamp(0, 4);
    final detail =
        safeStage == 2 && currentQuestion != null && totalQuestions != null
        ? '${english ? 'Question' : '第'} $currentQuestion/$totalQuestions${english ? '' : ' 题'}'
        : null;
    return AlertDialog(
      title: Text(english ? 'Generating paper' : '正在生成试卷'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            (english ? enStages : zhStages)[safeStage],
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (detail != null) ...[const SizedBox(height: 4), Text(detail)],
          const SizedBox(height: 8),
          Text(
            english
                ? 'Progress is based on real stages rather than an estimated percentage.'
                : '进度按真实阶段展示，不使用虚假的精确百分比。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: Text(english ? 'Cancel' : '取消生成'),
          ),
      ],
    );
  }
}
