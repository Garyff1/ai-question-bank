import 'package:flutter_test/flutter_test.dart';

import 'package:ai_question_bank_android/app/app_settings_controller.dart';
import 'package:ai_question_bank_android/features/materials/ocr/ocr_models.dart';

void main() {
  test('OCR page only succeeds with recognized text and no error', () {
    expect(const OcrPageResult(path: 'a.jpg', text: '有效文字').succeeded, isTrue);
    expect(
      const OcrPageResult(path: 'b.jpg', text: '', error: '未识别到文字').succeeded,
      isFalse,
    );
  });

  test('OCR language labels support Chinese and English UI', () {
    expect(OcrLanguageMode.mixed.label(false), '中英混合');
    expect(OcrLanguageMode.mixed.label(true), 'Chinese + English');
  });

  test('multi-page OCR keeps source order and excludes failed pages', () {
    const pages = [
      OcrPageResult(path: '1.jpg', text: '第一页中文教材'),
      OcrPageResult(path: '2.jpg', text: '', error: '已取消裁剪'),
      OcrPageResult(path: '3.jpg', text: 'Page three English content'),
    ];
    final merged = pages
        .where((page) => page.succeeded)
        .map((page) => page.text.trim())
        .join('\n\n');

    expect(merged, '第一页中文教材\n\nPage three English content');
    expect(pages.where((page) => page.succeeded), hasLength(2));
  });

  test('gallery page names use natural numeric order', () {
    final names = ['page-10.jpg', 'page-2.jpg', 'page-1.jpg', 'page-03.jpg']
      ..sort(compareOcrPageNames);

    expect(names, ['page-1.jpg', 'page-2.jpg', 'page-03.jpg', 'page-10.jpg']);
  });
}
