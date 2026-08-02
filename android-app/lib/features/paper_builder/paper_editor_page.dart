import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_settings_controller.dart';
import '../../core/motion/shared_element_route.dart';
import 'duplicate_question_detector.dart';
import 'models/paper_builder_models.dart';
import 'motion/paper_binding_transition.dart';
import 'paper_draft_storage.dart';
import 'paper_question_editor.dart';

typedef RegeneratePaperQuestion =
    Future<PaperEditorQuestion?> Function(
      PaperEditorQuestion question,
      String instruction,
    );

class PaperEditorPage extends StatefulWidget {
  const PaperEditorPage({
    super.key,
    required this.document,
    required this.onPreview,
    this.onRegenerate,
    this.onStartPractice,
  });

  final PaperEditorDocument document;
  final Future<void> Function(PaperEditorDocument document, bool teacher)
  onPreview;
  final RegeneratePaperQuestion? onRegenerate;
  final Future<void> Function(PaperEditorDocument document)? onStartPractice;

  @override
  State<PaperEditorPage> createState() => _PaperEditorPageState();
}

class _PaperEditorPageState extends State<PaperEditorPage>
    with WidgetsBindingObserver {
  late PaperEditorDocument _document;
  final _storage = PaperDraftStorage();
  Timer? _saveDebounce;
  bool _saving = false;
  bool _regenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _document = widget.document;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveNow();
  }

  void _changed(List<PaperEditorQuestion> questions) {
    setState(
      () => _document = _document.copyWith(
        questions: questions,
        updatedAt: DateTime.now(),
      ),
    );
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  Future<void> _saveNow() async {
    if (_saving) return;
    _saving = true;
    try {
      await _storage.saveEditor(_document.copyWith(updatedAt: DateTime.now()));
    } finally {
      _saving = false;
    }
  }

  Future<bool> _confirmDiscard() async {
    await _saveNow();
    if (!mounted) return true;
    final english = Localizations.localeOf(context).languageCode == 'en';
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(english ? 'Leave editor?' : '离开试卷编辑器？'),
            content: Text(
              english
                  ? 'Your draft has been saved and can be resumed later.'
                  : '当前修改已保存为草稿，下次可以继续编辑。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(english ? 'Keep editing' : '继续编辑'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(english ? 'Leave' : '离开'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _document.questions.length) return;
    final questions = [..._document.questions];
    final item = questions.removeAt(index);
    questions.insert(target, item);
    _changed(questions);
  }

  Future<void> _edit(int index) async {
    final edited = await showPaperQuestionEditor(
      context,
      _document.questions[index],
    );
    if (edited == null) return;
    final questions = [..._document.questions]..[index] = edited;
    _changed(questions);
  }

  Future<void> _preview(bool teacher) async {
    if (_document.questions.isEmpty) return;
    await Navigator.of(context).push<void>(
      SharedElementRoute<void>(
        opaque: false,
        barrierLabel: 'Paper binding preview',
        builder: (overlayContext) => PaperBindingPreviewRoute(
          questionCount: _document.questions.length,
          onReady: () => Navigator.of(overlayContext).pop(),
        ),
      ),
    );
    if (!mounted) return;
    await widget.onPreview(_document, teacher);
  }

  Future<void> _regenerate(int index) async {
    final callback = widget.onRegenerate;
    if (callback == null || _document.questions[index].locked) return;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final controller = TextEditingController();
    final instruction = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(english ? 'Regenerate this question' : '重新生成当前题'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              english
                  ? 'Only this question will be replaced. Other questions remain unchanged.'
                  : '仅替换当前题，试卷中的其他题目不会改变。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: english
                    ? 'e.g. Make it easier or use a real-life scenario'
                    : '例如：降低难度、改成生活化场景、避免与上一题相似',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(english ? 'Cancel' : '取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(english ? 'Regenerate' : '重新生成'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (instruction == null || !mounted) return;
    setState(() => _regenerating = true);
    try {
      final replacement = await callback(
        _document.questions[index],
        instruction,
      );
      if (replacement == null || !mounted) return;
      final useReplacement = await _compareReplacement(
        _document.questions[index],
        replacement,
      );
      if (useReplacement != true || !mounted) return;
      final questions = [..._document.questions]
        ..[index] = replacement.copyWith(
          id: _document.questions[index].id,
          section: _document.questions[index].section,
          score: _document.questions[index].score,
        );
      _changed(questions);
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<bool?> _compareReplacement(
    PaperEditorQuestion original,
    PaperEditorQuestion replacement,
  ) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(english ? 'Compare questions' : '对比新旧题目'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _ComparisonCard(
                  title: english ? 'Original question' : '原题',
                  question: original,
                  accent: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                _ComparisonCard(
                  title: english ? 'New question' : '新题',
                  question: replacement,
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(english ? 'Keep original' : '保留原题'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(english ? 'Use new question' : '使用新题'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    final duplicates = DuplicateQuestionDetector.detect(_document.questions);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(english ? 'Edit paper' : '编辑试卷'),
          actions: [
            TextButton(
              onPressed: () async {
                await _saveNow();
                if (context.mounted) Navigator.pop(context, _document);
              },
              child: Text(english ? 'Save' : '保存试卷'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: english ? 'Questions' : '题目',
                          value: '${_document.questions.length}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          label: english ? 'Total' : '总分',
                          value: '${_document.totalScore}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          label: english ? 'Duration' : '时长',
                          value: '${_document.durationMinutes}m',
                        ),
                      ),
                    ],
                  ),
                  if (duplicates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.copy_all_rounded,
                          color: scheme.onErrorContainer,
                        ),
                        title: Text(
                          english
                              ? '${duplicates.length} possible duplicate pair(s)'
                              : '发现 ${duplicates.length} 组可能重复的题目',
                        ),
                        subtitle: Text(
                          english
                              ? 'Review before exporting.'
                              : '请逐题检查后再导出，系统不会自动删除。',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _preview(false),
                          icon: const Icon(Icons.school_outlined),
                          label: Text(english ? 'Student' : '学生版预览'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _preview(true),
                          icon: const Icon(Icons.co_present_outlined),
                          label: Text(english ? 'Teacher' : '教师版预览'),
                        ),
                      ),
                    ],
                  ),
                  if (widget.onStartPractice != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _document.questions.isEmpty
                            ? null
                            : () async {
                                await _saveNow();
                                await widget.onStartPractice!(_document);
                              },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(english ? 'Start answering' : '开始答题'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_regenerating) const LinearProgressIndicator(),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: _document.questions.length,
                onReorder: (oldIndex, newIndex) {
                  final questions = [..._document.questions];
                  if (newIndex > oldIndex) newIndex--;
                  final item = questions.removeAt(oldIndex);
                  questions.insert(newIndex, item);
                  _changed(questions);
                  final settings = AppSettingsScope.maybeOf(context);
                  if (settings?.hapticsEnabled ?? true) {
                    HapticFeedback.selectionClick();
                  }
                },
                proxyDecorator: (child, index, animation) {
                  final settings = AppSettingsScope.maybeOf(context);
                  final reduceMotion = settings?.reduceMotion ?? false;
                  return AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, child) => Transform.rotate(
                      angle: reduceMotion ? 0 : .018 * animation.value,
                      child: Material(
                        elevation: reduceMotion ? 1 : 10 * animation.value,
                        borderRadius: BorderRadius.circular(22),
                        child: child,
                      ),
                    ),
                  );
                },
                itemBuilder: (context, index) {
                  final question = _document.questions[index];
                  return Card(
                    key: ValueKey(question.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  question.knowledgePoint.isEmpty
                                      ? question.type
                                      : question.knowledgePoint,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (question.needsReview)
                                const Chip(
                                  label: Text('待检查'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              Icon(
                                question.locked
                                    ? Icons.lock_rounded
                                    : Icons.drag_handle_rounded,
                                color: question.locked
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            question.prompt,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                tooltip: english ? 'Edit' : '编辑',
                                onPressed: () => _edit(index),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: english ? 'Move up' : '上移',
                                onPressed: index == 0
                                    ? null
                                    : () => _move(index, -1),
                                icon: const Icon(Icons.arrow_upward_rounded),
                              ),
                              IconButton(
                                tooltip: english ? 'Move down' : '下移',
                                onPressed:
                                    index == _document.questions.length - 1
                                    ? null
                                    : () => _move(index, 1),
                                icon: const Icon(Icons.arrow_downward_rounded),
                              ),
                              IconButton(
                                tooltip: english ? 'Duplicate' : '复制',
                                onPressed: () {
                                  final questions = [..._document.questions]
                                    ..insert(
                                      index + 1,
                                      question.copyWith(
                                        id: '${question.id}-copy-${DateTime.now().millisecondsSinceEpoch}',
                                      ),
                                    );
                                  _changed(questions);
                                },
                                icon: const Icon(Icons.copy_rounded),
                              ),
                              IconButton(
                                tooltip: question.locked
                                    ? (english ? 'Unlock' : '解锁')
                                    : (english ? 'Lock' : '锁定'),
                                onPressed: () {
                                  final questions = [..._document.questions]
                                    ..[index] = question.copyWith(
                                      locked: !question.locked,
                                    );
                                  _changed(questions);
                                },
                                icon: Icon(
                                  question.locked
                                      ? Icons.lock_open_rounded
                                      : Icons.lock_outline_rounded,
                                ),
                              ),
                              IconButton(
                                tooltip: english ? 'Mark for review' : '标记待检查',
                                onPressed: () {
                                  final questions = [..._document.questions]
                                    ..[index] = question.copyWith(
                                      needsReview: !question.needsReview,
                                    );
                                  _changed(questions);
                                },
                                icon: Icon(
                                  question.needsReview
                                      ? Icons.flag_rounded
                                      : Icons.flag_outlined,
                                ),
                              ),
                              IconButton(
                                tooltip: english
                                    ? 'Regenerate only this question'
                                    : '只重新生成本题',
                                onPressed: question.locked || _regenerating
                                    ? null
                                    : () => _regenerate(index),
                                icon: const Icon(Icons.auto_awesome_rounded),
                              ),
                              IconButton(
                                tooltip: english ? 'Delete' : '删除',
                                color: scheme.error,
                                onPressed: () {
                                  final questions = [..._document.questions]
                                    ..removeAt(index);
                                  _changed(questions);
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    super.dispose();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.title,
    required this.question,
    required this.accent,
  });

  final String title;
  final PaperEditorQuestion question;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: accent, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          question.prompt,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (question.options.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(option),
            ),
          ),
        ],
      ],
    ),
  );
}
