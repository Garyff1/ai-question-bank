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
}
