import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/motion/motion_states.dart';
import '../../core/theme/app_theme.dart';
import '../generation/motion/knowledge_forge_view.dart';
import '../paper_builder/motion/answer_layer_reveal.dart';
import '../paper_builder/motion/paper_binding_transition.dart';
import '../provider_portal/provider_portal.dart';
import 'demo_data.dart';
import 'motion_lab_controls.dart';

const bool kMotionLabEnabled =
    kDebugMode || bool.fromEnvironment('INTERNAL_BUILD');

enum MotionLabDemo {
  servicePortal,
  knowledgeForge,
  paperBinding,
  questionLift,
  reorder,
  answerLayer,
  ocrLens,
}

class MotionLabPage extends StatefulWidget {
  const MotionLabPage({super.key});

  @override
  State<MotionLabPage> createState() => _MotionLabPageState();
}

class _MotionLabPageState extends State<MotionLabPage> {
  MotionLabDemo _demo = MotionLabDemo.knowledgeForge;
  bool _playing = false;
  bool _dark = false;
  bool _english = false;
  bool _reduceMotion = false;
  bool _lowPerformance = false;
  bool _showAnswers = false;
  bool _lifted = false;
  double _speed = 1;
  int _runId = 0;
  int _stage = 0;
  List<String> _reorderItems = const ['读取资料', '提取知识', '生成题目', '检查结果'];

  Duration get _stepDuration => Duration(milliseconds: (650 / _speed).round());

  void _playPause() {
    if (_playing) {
      setState(() => _playing = false);
      _runId++;
      return;
    }
    setState(() => _playing = true);
    _run();
  }

  void _replay() {
    _runId++;
    setState(() {
      _stage = 0;
      _showAnswers = false;
      _lifted = false;
      _playing = true;
    });
    _run();
  }

  Future<void> _run() async {
    final run = ++_runId;
    final count = _demo == MotionLabDemo.knowledgeForge
        ? GenerateMotionState.values.length - 3
        : _demo == MotionLabDemo.paperBinding
        ? PaperBindingState.values.length - 2
        : 2;
    for (var i = _stage + 1; i < count; i++) {
      await Future<void>.delayed(
        _reduceMotion ? const Duration(milliseconds: 160) : _stepDuration,
      );
      if (!mounted || run != _runId || !_playing) return;
      setState(() {
        _stage = i;
        if (_demo == MotionLabDemo.answerLayer) _showAnswers = i.isOdd;
        if (_demo == MotionLabDemo.questionLift) _lifted = i.isOdd;
      });
    }
    if (mounted && run == _runId) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _dark ? AppTheme.dark : AppTheme.light;
    return Theme(
      data: theme,
      child: Localizations.override(
        context: context,
        locale: Locale(_english ? 'en' : 'zh'),
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Motion Lab · 动效实验室'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(
                    avatar: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('INTERNAL'),
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                DropdownButtonFormField<MotionLabDemo>(
                  initialValue: _demo,
                  decoration: const InputDecoration(
                    labelText: '预览项目',
                    prefixIcon: Icon(Icons.animation_rounded),
                  ),
                  items: MotionLabDemo.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_demoName(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _runId++;
                    setState(() {
                      _demo = value;
                      _stage = 0;
                      _playing = false;
                      _showAnswers = false;
                      _lifted = false;
                    });
                  },
                ),
                const SizedBox(height: 12),
                MotionLabControls(
                  playing: _playing,
                  speed: _speed,
                  dark: _dark,
                  english: _english,
                  reduceMotion: _reduceMotion,
                  lowPerformance: _lowPerformance,
                  onPlayPause: _playPause,
                  onReplay: _replay,
                  onSpeedChanged: (value) => setState(() => _speed = value),
                  onDarkChanged: (value) => setState(() => _dark = value),
                  onEnglishChanged: (value) => setState(() => _english = value),
                  onReduceMotionChanged: (value) =>
                      setState(() => _reduceMotion = value),
                  onLowPerformanceChanged: (value) =>
                      setState(() => _lowPerformance = value),
                ),
                const SizedBox(height: 16),
                _buildDemo(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemo(BuildContext context) => switch (_demo) {
    MotionLabDemo.servicePortal => _ServicePortalDemo(
      reduceMotion: _reduceMotion,
      lowPerformance: _lowPerformance,
    ),
    MotionLabDemo.knowledgeForge => KnowledgeForgeView(
      state: GenerateMotionState.values[_stage.clamp(0, 6)],
      materialName: MotionLabDemoData.materialName,
      enabledTypes: MotionLabDemoData.questionTypes,
      actualQuestionCount: _stage >= 4 ? 5 : null,
      totalQuestions: 5,
      reduceMotionOverride: _reduceMotion,
      lowPerformance: _lowPerformance,
    ),
    MotionLabDemo.paperBinding => PaperBindingTransition(
      state: PaperBindingState.values[_stage.clamp(0, 7)],
      questionCount: 20,
      reduceMotionOverride: _reduceMotion,
      lowPerformance: _lowPerformance,
    ),
    MotionLabDemo.questionLift => _QuestionLiftDemo(
      lifted: _lifted,
      reduceMotion: _reduceMotion,
      onTap: () => setState(() => _lifted = !_lifted),
    ),
    MotionLabDemo.reorder => _ReorderDemo(
      items: _reorderItems,
      reduceMotion: _reduceMotion,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final result = [..._reorderItems];
        result.insert(newIndex, result.removeAt(oldIndex));
        setState(() => _reorderItems = result);
      },
    ),
    MotionLabDemo.answerLayer => _AnswerLayerDemo(
      visible: _showAnswers,
      onToggle: () => setState(() => _showAnswers = !_showAnswers),
    ),
    MotionLabDemo.ocrLens => const _OcrLensMock(),
  };

  String _demoName(MotionLabDemo demo) => switch (demo) {
    MotionLabDemo.servicePortal => '模型服务商传送门',
    MotionLabDemo.knowledgeForge => '知识炼成生成过程',
    MotionLabDemo.paperBinding => '题目卡片形成试卷',
    MotionLabDemo.questionLift => '单题抬起编辑',
    MotionLabDemo.reorder => '题目拖动排序',
    MotionLabDemo.answerLayer => '学生版 / 教师版答案层',
    MotionLabDemo.ocrLens => 'OCR 扫描镜',
  };
}

class _ServicePortalDemo extends StatelessWidget {
  const _ServicePortalDemo({
    required this.reduceMotion,
    required this.lowPerformance,
  });
  final bool reduceMotion;
  final bool lowPerformance;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.hub_rounded, size: 54),
          const SizedBox(height: 12),
          const Text(
            '预览模型服务商之间的空间切换，不读取或展示 API Key。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showProviderPortal(
              context,
              currentProviderId: 'deepseek',
              keyConfigured: false,
              currentModel: 'deepseek-v4-flash',
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('打开传送门'),
          ),
        ],
      ),
    ),
  );
}

class _QuestionLiftDemo extends StatelessWidget {
  const _QuestionLiftDemo({
    required this.lifted,
    required this.reduceMotion,
    required this.onTap,
  });
  final bool lifted;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 340,
    child: Stack(
      alignment: Alignment.center,
      children: [
        AnimatedScale(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 360),
          scale: lifted ? .96 : 1,
          child: Container(
            margin: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          width: lifted ? 310 : 270,
          padding: const EdgeInsets.all(18),
          transform: Matrix4.translationValues(0, lifted ? -24 : 0, 0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Theme.of(context).colorScheme.primary),
            boxShadow: lifted
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .2),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1 · 光合作用',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text('光合作用发生的主要场所是什么？'),
              if (lifted) ...[
                const SizedBox(height: 14),
                const TextField(decoration: InputDecoration(labelText: '编辑题干')),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onTap,
                child: Text(lifted ? '放回试卷' : '抬起编辑'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReorderDemo extends StatelessWidget {
  const _ReorderDemo({
    required this.items,
    required this.reduceMotion,
    required this.onReorder,
  });
  final List<String> items;
  final bool reduceMotion;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 340,
    child: ReorderableListView.builder(
      itemCount: items.length,
      onReorder: onReorder,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform.rotate(
          angle: reduceMotion ? 0 : .018 * animation.value,
          child: Material(
            elevation: reduceMotion ? 1 : 9 * animation.value,
            borderRadius: BorderRadius.circular(18),
            child: child,
          ),
        ),
      ),
      itemBuilder: (context, index) => Card(
        key: ValueKey(items[index]),
        child: ListTile(
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(items[index]),
          trailing: const Icon(Icons.drag_handle_rounded),
        ),
      ),
    ),
  );
}

class _AnswerLayerDemo extends StatelessWidget {
  const _AnswerLayerDemo({required this.visible, required this.onToggle});
  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('学生版')),
              ButtonSegment(value: true, label: Text('教师版')),
            ],
            selected: {visible},
            onSelectionChanged: (_) => onToggle(),
          ),
          const SizedBox(height: 18),
          const Text('1. 光合作用发生的主要场所是什么？'),
          const SizedBox(height: 8),
          const Text('A. 细胞核   B. 叶绿体   C. 液泡'),
          const SizedBox(height: 10),
          AnswerLayerReveal(
            visible: visible,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('答案：B\n解析：叶绿体中的叶绿素能够吸收光能。'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OcrLensMock extends StatefulWidget {
  const _OcrLensMock();

  @override
  State<_OcrLensMock> createState() => _OcrLensMockState();
}

class _OcrLensMockState extends State<_OcrLensMock> {
  double _split = .55;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 360,
    child: LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onHorizontalDragUpdate: (details) => setState(
          () => _split = (details.localPosition.dx / constraints.maxWidth)
              .clamp(.1, .9),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      '光合作用是绿色植物利用光能，将二氧化碳和水转化为有机物的过程。',
                      style: TextStyle(fontSize: 20, height: 1.8),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * _split,
                top: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '识别结果\n\n光合作用是绿色植物利用光能，将二氧化碳和水转化为有机物的过程。\n\n请人工校对后保存。',
                      style: TextStyle(height: 1.6),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * _split - 2,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
