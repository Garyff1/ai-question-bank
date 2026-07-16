import '../../../app/app_settings_controller.dart';

int compareOcrPageNames(String left, String right) {
  final leftParts = RegExp(r'\d+|\D+')
      .allMatches(left.toLowerCase())
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final rightParts = RegExp(r'\d+|\D+')
      .allMatches(right.toLowerCase())
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final length = leftParts.length < rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var i = 0; i < length; i++) {
    final leftNumber = int.tryParse(leftParts[i]);
    final rightNumber = int.tryParse(rightParts[i]);
    final comparison = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : leftParts[i].compareTo(rightParts[i]);
    if (comparison != 0) return comparison;
  }
  return leftParts.length.compareTo(rightParts.length);
}

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
