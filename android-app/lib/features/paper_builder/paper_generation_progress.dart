import 'package:flutter/material.dart';

import '../../core/motion/motion_states.dart';
import '../generation/motion/knowledge_forge_view.dart';
import 'motion/paper_binding_transition.dart';

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
    final safeStage = stage.clamp(0, 4);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(english ? 'Knowledge Forge' : '知识炼成 · 试卷生成')),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      content: SizedBox(
        width: 420,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: safeStage == 4
              ? PaperBindingTransition(
                  key: const ValueKey('binding'),
                  state: PaperBindingState.binding,
                  questionCount: totalQuestions ?? currentQuestion ?? 0,
                  compact: true,
                )
              : KnowledgeForgeView(
                  key: const ValueKey('forge'),
                  state: _forgeState(safeStage),
                  actualQuestionCount: currentQuestion,
                  totalQuestions: totalQuestions,
                  compact: true,
                ),
        ),
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

  GenerateMotionState _forgeState(int stage) => switch (stage) {
    0 => GenerateMotionState.readingMaterial,
    1 => GenerateMotionState.planningTypes,
    2 => GenerateMotionState.generatingQuestions,
    3 => GenerateMotionState.validating,
    _ => GenerateMotionState.completed,
  };
}
