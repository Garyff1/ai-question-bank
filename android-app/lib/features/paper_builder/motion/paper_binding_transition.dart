import 'package:flutter/material.dart';

import '../../../core/motion/app_motion_tokens.dart';
import '../../../core/motion/motion_preferences.dart';
import '../../../core/motion/motion_states.dart';
import 'paper_page_stack.dart';

class PaperBindingTransition extends StatelessWidget {
  const PaperBindingTransition({
    super.key,
    required this.state,
    required this.questionCount,
    this.reduceMotionOverride,
    this.lowPerformance = false,
    this.compact = false,
  });

  final PaperBindingState state;
  final int questionCount;
  final bool? reduceMotionOverride;
  final bool lowPerformance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    final prefs = MotionPreferences.of(
      context,
      simulateLowPerformance: lowPerformance,
    );
    final reduce = reduceMotionOverride ?? prefs.reduceMotion;
    final duration = AppMotionTokens.resolve(
      reduceMotion: reduce,
      regular: AppMotionTokens.binding,
    );
    final progress = _progress(state);
    return Semantics(
      liveRegion: true,
      label: _label(state, english),
      child: Container(
        padding: EdgeInsets.all(compact ? 16 : 24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(compact ? 22 : 28),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => PaperPageStack(
                progress: value,
                questionCount: questionCount,
                color: scheme.primary,
                compact: compact,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: reduce
                  ? AppMotionTokens.reduced
                  : AppMotionTokens.selection,
              child: Text(
                _label(state, english),
                key: ValueKey(state),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              state == PaperBindingState.failed
                  ? (english
                        ? 'Questions are preserved. You can return to editing.'
                        : '题目内容已保留，可以返回编辑后重试。')
                  : (english
                        ? 'Questions are becoming a printable paper.'
                        : '题目正在排列、分页并形成可打印试卷。'),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  double _progress(PaperBindingState state) => switch (state) {
    PaperBindingState.idle => 0,
    PaperBindingState.grouping => .18,
    PaperBindingState.numbering => .36,
    PaperBindingState.layingOut => .58,
    PaperBindingState.binding => .78,
    PaperBindingState.openingPreview => .94,
    PaperBindingState.completed => 1,
    PaperBindingState.failed => .2,
  };

  String _label(PaperBindingState state, bool english) => switch (state) {
    PaperBindingState.idle => english ? 'Ready to bind' : '准备装订',
    PaperBindingState.grouping => english ? 'Grouping questions' : '正在按题型分组',
    PaperBindingState.numbering =>
      english ? 'Numbering questions' : '正在编排题号和分值',
    PaperBindingState.layingOut => english ? 'Laying out pages' : '正在排版与分页',
    PaperBindingState.binding => english ? 'Binding paper' : '正在装订试卷',
    PaperBindingState.openingPreview => english ? 'Opening preview' : '正在展开第一页',
    PaperBindingState.completed => english ? 'Paper ready' : '试卷装订完成',
    PaperBindingState.failed => english ? 'Layout failed' : '试卷排版未完成',
  };
}

class PaperBindingPreviewRoute extends StatefulWidget {
  const PaperBindingPreviewRoute({
    super.key,
    required this.questionCount,
    required this.onReady,
  });

  final int questionCount;
  final VoidCallback onReady;

  @override
  State<PaperBindingPreviewRoute> createState() =>
      _PaperBindingPreviewRouteState();
}

class _PaperBindingPreviewRouteState extends State<PaperBindingPreviewRoute> {
  PaperBindingState _state = PaperBindingState.grouping;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final reduce = MotionPreferences.of(context).reduceMotion;
    final delay = reduce
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 150);
    for (final state in const [
      PaperBindingState.numbering,
      PaperBindingState.layingOut,
      PaperBindingState.binding,
      PaperBindingState.openingPreview,
      PaperBindingState.completed,
    ]) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      setState(() => _state = state);
    }
    if (_completed || !mounted) return;
    _completed = true;
    widget.onReady();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .62),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: PaperBindingTransition(
          state: _state,
          questionCount: widget.questionCount,
        ),
      ),
    ),
  );
}
