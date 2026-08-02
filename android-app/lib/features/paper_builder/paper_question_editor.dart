import 'package:flutter/material.dart';

import '../../app/app_settings_controller.dart';
import 'models/paper_builder_models.dart';

Future<PaperEditorQuestion?> showPaperQuestionEditor(
  BuildContext context,
  PaperEditorQuestion question,
) async {
  final prompt = TextEditingController(text: question.prompt);
  final options = TextEditingController(text: question.options.join('\n'));
  final answer = TextEditingController(
    text: question.answer is List
        ? (question.answer as List).join(',')
        : question.answer?.toString() ?? '',
  );
  final explanation = TextEditingController(text: question.explanation);
  final knowledgePoint = TextEditingController(text: question.knowledgePoint);
  final score = TextEditingController(text: question.score.toString());
  var type = question.type;
  final english = Localizations.localeOf(context).languageCode == 'en';
  final reduceMotion =
      AppSettingsScope.maybeOf(context)?.reduceMotion ??
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
  final result = await showGeneralDialog<PaperEditorQuestion>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: .58),
    transitionDuration: reduceMotion
        ? const Duration(milliseconds: 140)
        : const Duration(milliseconds: 420),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      if (reduceMotion) return FadeTransition(opacity: curved, child: child);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .08),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: .9, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (context, _, _) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(english ? 'Edit question' : '编辑题目'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: english ? 'Question type' : '题型',
                  ),
                  items:
                      const {
                            'choice': '单选题',
                            'multi_choice': '多选题',
                            'true_false': '判断题',
                            'fill': '填空题',
                            'subjective': '主观题',
                          }.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: prompt,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: english ? 'Question' : '题干',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: options,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: english ? 'Options (one per line)' : '选项（每行一项）',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: answer,
                  decoration: InputDecoration(
                    labelText: english ? 'Answer' : '正确答案',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: explanation,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: english ? 'Explanation' : '解析',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: knowledgePoint,
                  decoration: InputDecoration(
                    labelText: english ? 'Knowledge point' : '知识点',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: score,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: english ? 'Score' : '分值',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(english ? 'Cancel' : '取消'),
          ),
          FilledButton(
            onPressed: () {
              final promptText = prompt.text.trim();
              if (promptText.isEmpty) return;
              Object parsedAnswer = answer.text.trim();
              if (type == 'multi_choice') {
                parsedAnswer = answer.text
                    .split(RegExp(r'[,，\s]+'))
                    .where((e) => e.trim().isNotEmpty)
                    .toList();
              }
              Navigator.pop(
                context,
                question.copyWith(
                  type: type,
                  prompt: promptText,
                  options: options.text
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  answer: parsedAnswer,
                  explanation: explanation.text.trim(),
                  knowledgePoint: knowledgePoint.text.trim(),
                  score: int.tryParse(score.text) ?? question.score,
                ),
              );
            },
            child: Text(english ? 'Save' : '保存'),
          ),
        ],
      ),
    ),
  );
  prompt.dispose();
  options.dispose();
  answer.dispose();
  explanation.dispose();
  knowledgePoint.dispose();
  score.dispose();
  return result;
}
