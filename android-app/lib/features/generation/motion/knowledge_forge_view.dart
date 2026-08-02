import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/app_motion_tokens.dart';
import '../../../core/motion/motion_preferences.dart';
import '../../../core/motion/motion_states.dart';
import 'knowledge_node.dart';
import 'question_card_stack.dart';

class KnowledgeForgeView extends StatefulWidget {
  const KnowledgeForgeView({
    super.key,
    required this.state,
    this.materialName,
    this.enabledTypes = const [],
    this.actualQuestionCount,
    this.totalQuestions,
    this.onCancel,
    this.compact = false,
    this.reduceMotionOverride,
    this.lowPerformance = false,
  });

  final GenerateMotionState state;
  final String? materialName;
  final List<String> enabledTypes;
  final int? actualQuestionCount;
  final int? totalQuestions;
  final VoidCallback? onCancel;
  final bool compact;
  final bool? reduceMotionOverride;
  final bool lowPerformance;

  @override
  State<KnowledgeForgeView> createState() => _KnowledgeForgeViewState();
}

class _KnowledgeForgeViewState extends State<KnowledgeForgeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant KnowledgeForgeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final prefs = MotionPreferences.of(
      context,
      simulateLowPerformance: widget.lowPerformance,
    );
    final reduce = widget.reduceMotionOverride ?? prefs.reduceMotion;
    if (!reduce && !widget.lowPerformance && _active(widget.state)) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
  }

  bool _active(GenerateMotionState state) =>
      state.index >= GenerateMotionState.readingMaterial.index &&
      state.index <= GenerateMotionState.validating.index;

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    final motion = MotionSemanticColors.from(scheme);
    final prefs = MotionPreferences.of(
      context,
      simulateLowPerformance: widget.lowPerformance,
    );
    final reduce = widget.reduceMotionOverride ?? prefs.reduceMotion;
    final duration = AppMotionTokens.resolve(
      reduceMotion: reduce,
      regular: AppMotionTokens.selection,
    );
    final stage = _stageText(widget.state, english);
    final types = widget.enabledTypes.isEmpty
        ? (english
              ? const ['Choice', 'Fill', 'Reasoning']
              : const ['选择', '填空', '主观'])
        : widget.enabledTypes.map((item) => _typeLabel(item, english)).toList();
    final nodeVisible =
        widget.state.index >= GenerateMotionState.planningTypes.index;
    final count = widget.actualQuestionCount;

    return Semantics(
      liveRegion: true,
      label: stage,
      child: Container(
        padding: EdgeInsets.all(widget.compact ? 16 : 22),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(widget.compact ? 22 : 28),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.materialName != null) ...[
              Row(
                children: [
                  Icon(Icons.description_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.materialName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            AnimatedBuilder(
              animation: _breath,
              builder: (context, _) {
                final pulse = 1 + _breath.value * .05;
                return SizedBox(
                  height: widget.compact ? 118 : 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!reduce && !widget.lowPerformance)
                        Transform.scale(
                          scale: pulse,
                          child: Container(
                            width: widget.compact ? 88 : 118,
                            height: widget.compact ? 88 : 118,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  motion.forgeCore.withValues(alpha: .2),
                                  motion.forgeCore.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      AnimatedContainer(
                        duration: duration,
                        width: widget.compact ? 58 : 72,
                        height: widget.compact ? 58 : 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [scheme.primary, motion.forgeCore],
                          ),
                          boxShadow: reduce
                              ? null
                              : [
                                  BoxShadow(
                                    color: motion.forgeCore.withValues(
                                      alpha: .28,
                                    ),
                                    blurRadius: 24 + _breath.value * 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                        ),
                        child: Icon(
                          widget.state == GenerateMotionState.completed
                              ? Icons.check_rounded
                              : widget.state == GenerateMotionState.failed
                              ? Icons.error_outline_rounded
                              : Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: widget.compact ? 27 : 34,
                        ),
                      ),
                      for (var i = 0; i < math.min(types.length, 5); i++)
                        AnimatedPositioned(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          left: nodeVisible
                              ? _nodeOffset(i, types.length, widget.compact).dx
                              : (widget.compact ? 49 : 72),
                          top: nodeVisible
                              ? _nodeOffset(i, types.length, widget.compact).dy
                              : (widget.compact ? 46 : 67),
                          child: KnowledgeNode(
                            label: types[i],
                            progress: nodeVisible ? 1 : 0,
                            color: i.isEven ? scheme.primary : scheme.tertiary,
                            compact: widget.compact,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            AnimatedSwitcher(
              duration: duration,
              child: Text(
                stage,
                key: ValueKey(widget.state),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _detail(widget.state, english),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(height: 12),
              QuestionCardStack(count: count, color: scheme.primary),
              if (widget.totalQuestions != null)
                Text(
                  '$count / ${widget.totalQuestions}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
            ],
            if (widget.onCancel != null && _active(widget.state)) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(english ? 'Cancel' : '取消'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Offset _nodeOffset(int index, int count, bool compact) {
    final center = compact ? const Offset(59, 54) : const Offset(92, 78);
    final radiusX = compact ? 44.0 : 68.0;
    final radiusY = compact ? 38.0 : 56.0;
    final angle = -math.pi / 2 + index * (2 * math.pi / math.max(count, 1));
    return Offset(
      center.dx + math.cos(angle) * radiusX - (compact ? 18 : 24),
      center.dy + math.sin(angle) * radiusY - 10,
    );
  }

  String _stageText(GenerateMotionState state, bool english) => switch (state) {
    GenerateMotionState.idle => english ? 'Ready' : '准备就绪',
    GenerateMotionState.readingMaterial =>
      english ? 'Reading material' : '正在读取资料',
    GenerateMotionState.extractingKnowledge =>
      english ? 'Extracting knowledge' : '正在提取知识',
    GenerateMotionState.planningTypes =>
      english ? 'Planning question types' : '正在规划题型',
    GenerateMotionState.generatingQuestions =>
      english ? 'Generating questions' : '正在生成题目',
    GenerateMotionState.validating => english ? 'Checking results' : '正在检查结果',
    GenerateMotionState.completed => english ? 'Ready to learn' : '题目整理完成',
    GenerateMotionState.failed => english ? 'Generation interrupted' : '生成未完成',
    GenerateMotionState.cancelled => english ? 'Generation cancelled' : '已取消生成',
  };

  String _detail(GenerateMotionState state, bool english) => switch (state) {
    GenerateMotionState.generatingQuestions =>
      english
          ? 'The core is waiting for the real model result. No fake question count is shown.'
          : '正在等待模型返回真实结果，不显示虚假的逐题进度。',
    GenerateMotionState.failed =>
      english
          ? 'Your material and draft are still available.'
          : '资料与草稿仍然保留，可以稍后重试。',
    _ =>
      english
          ? 'Knowledge Forge follows the real task stage.'
          : '知识炼成会跟随真实任务阶段变化。',
  };

  String _typeLabel(String type, bool english) => switch (type) {
    'choice' => english ? 'Choice' : '单选',
    'multi_choice' => english ? 'Multiple' : '多选',
    'true_false' => english ? 'True/False' : '判断',
    'fill' => english ? 'Fill' : '填空',
    'subjective' => english ? 'Written' : '主观',
    'chart' => english ? 'Chart' : '图表',
    'listening' => english ? 'Listening' : '听力',
    _ => type,
  };
}
