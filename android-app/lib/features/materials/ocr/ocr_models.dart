import '../../../app/app_settings_controller.dart';

class OcrMaterialDraft {
  const OcrMaterialDraft({
    required this.title,
    required this.content,
    required this.pageCount,
  });

  final String title;
  final String content;
  final int pageCount;
}

class OcrPageResult {
  const OcrPageResult({required this.path, required this.text, this.error});

  final String path;
  final String text;
  final String? error;

  bool get succeeded => error == null && text.trim().isNotEmpty;
}

extension OcrLanguageModeLabel on OcrLanguageMode {
  String label(bool englishUi) => switch (this) {
    OcrLanguageMode.auto => englishUi ? 'Auto' : '自动',
    OcrLanguageMode.chinese => englishUi ? 'Chinese' : '中文',
    OcrLanguageMode.english => englishUi ? 'English' : '英文',
    OcrLanguageMode.mixed => englishUi ? 'Chinese + English' : '中英混合',
  };
}
