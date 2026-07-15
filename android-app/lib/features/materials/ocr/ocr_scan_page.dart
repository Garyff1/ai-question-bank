import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_settings_controller.dart';
import 'ocr_models.dart';
import 'ocr_service.dart';

class OcrScanPage extends StatefulWidget {
  const OcrScanPage({super.key});

  @override
  State<OcrScanPage> createState() => _OcrScanPageState();
}

class _OcrScanPageState extends State<OcrScanPage> {
  final _picker = ImagePicker();
  final _service = const OcrService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<OcrPageResult> _pages = [];
  bool _working = false;
  int _processed = 0;
  int _totalToProcess = 0;

  bool get _english => Localizations.localeOf(context).languageCode == 'en';
  String _t(String zh, String en) => _english ? en : zh;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 96,
      );
      if (image != null) await _process([image]);
    } catch (error) {
      _showError(_t('无法打开相机：$error', 'Unable to open camera: $error'));
    }
  }

  Future<void> _pickGallery() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 96, limit: 20);
      if (images.isNotEmpty) await _process(images);
    } catch (error) {
      _showError(_t('无法选择图片：$error', 'Unable to select images: $error'));
    }
  }

  Future<void> _process(List<XFile> images) async {
    if (_working) return;
    setState(() {
      _working = true;
      _processed = 0;
      _totalToProcess = images.length;
    });
    final mode = AppSettingsScope.of(context).ocrLanguage;
    final results = <OcrPageResult>[];
    try {
      for (var i = 0; i < images.length; i++) {
        if (!mounted) return;
        final original = images[i].path;
        String path = original;
        try {
          path = await _service.cropForDocument(original) ?? original;
        } catch (error) {
          debugPrint('[OCR] crop cancelled or failed: $error');
        }
        final result = await _service.recognizePage(path, mode);
        results.add(result);
        if (mounted) setState(() => _processed = i + 1);
      }
      if (!mounted) return;
      setState(() {
        _pages.addAll(results);
        final recognized = _pages
            .where((page) => page.succeeded)
            .map((page) => page.text.trim())
            .join('\n\n');
        _contentController.text = recognized;
        if (_titleController.text.trim().isEmpty && recognized.isNotEmpty) {
          _titleController.text = _t(
            '扫描资料 ${DateTime.now().month}月${DateTime.now().day}日',
            'Scanned material ${DateTime.now().month}/${DateTime.now().day}',
          );
        }
      });
      if (results.every((page) => !page.succeeded)) {
        _showError(
          _t(
            '没有识别到有效文字，请换一张更清晰的图片。',
            'No text was recognized. Try a clearer image.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.length < 10) {
      _showError(
        _t(
          '请填写资料名称，并保留至少 10 个字的识别内容。',
          'Add a title and keep at least 10 characters of recognized text.',
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      OcrMaterialDraft(
        title: title,
        content: content,
        pageCount: _pages.length,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mode = AppSettingsScope.of(context).ocrLanguage;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('扫描资料', 'Scan material')),
        actions: [
          TextButton(
            onPressed: _working ? null : _save,
            child: Text(_t('保存', 'Save')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('拍摄或选择纸质资料', 'Capture or select pages'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        '支持多页中英文教材、打印资料和笔记。每页可先裁剪、旋转，再在本机识别。',
                        'Supports multi-page Chinese and English textbooks, printouts and notes. Crop and rotate before on-device recognition.',
                      ),
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Chip(
                      avatar: const Icon(Icons.translate_rounded, size: 18),
                      label: Text(
                        '${_t('识别语言', 'Recognition')}: ${mode.label(_english)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _working ? null : _pickCamera,
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: Text(_t('拍照', 'Camera')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _working ? null : _pickGallery,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(_t('选择图片', 'Gallery')),
                          ),
                        ),
                      ],
                    ),
                    if (_working) ...[
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: _totalToProcess == 0
                            ? null
                            : _processed / _totalToProcess,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          '正在处理第 ${(_processed + 1).clamp(1, _totalToProcess)} / $_totalToProcess 页…',
                          'Processing page ${(_processed + 1).clamp(1, _totalToProcess)} of $_totalToProcess…',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: _t('资料名称', 'Material title'),
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contentController,
              minLines: 12,
              maxLines: 24,
              decoration: InputDecoration(
                labelText: _t('识别文本（可编辑）', 'Recognized text (editable)'),
                alignLabelWithHint: true,
                hintText: _t(
                  '识别完成后，可在这里校对文字。',
                  'Review and edit recognized text here.',
                ),
              ),
            ),
            if (_pages.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _t('识别结果', 'Recognition results'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._pages.asMap().entries.map((entry) {
                final page = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    page.succeeded
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: page.succeeded ? Colors.green : colors.error,
                  ),
                  title: Text(
                    _t('第 ${entry.key + 1} 页', 'Page ${entry.key + 1}'),
                  ),
                  subtitle: Text(
                    page.succeeded
                        ? _t(
                            '${page.text.length} 个字符',
                            '${page.text.length} characters',
                          )
                        : (page.error ?? _t('识别失败', 'Recognition failed')),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _working ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_t('保存为学习资料', 'Save as material')),
            ),
          ],
        ),
      ),
    );
  }
}
