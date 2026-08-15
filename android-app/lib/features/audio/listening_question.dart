class ListeningQuestionData {
  const ListeningQuestionData({
    required this.script,
    this.voiceLocale = 'en-US',
  });

  final String script;
  final String voiceLocale;

  bool get isValid => script.trim().isNotEmpty;

  Map<String, dynamic> toRichContent() => {
    'type': 'listening',
    'data': {'audio_text': script, 'voice': voiceLocale},
  };

  static ListeningQuestionData fromJson(Map<String, dynamic> json) {
    var script = (json['listening_script'] ?? '').toString();
    var locale = (json['voice_locale'] ?? 'en-US').toString();
    if (script.trim().isEmpty) {
      final rich = json['rich_content'];
      if (rich is List) {
        for (final item in rich.whereType<Map>()) {
          if ((item['type'] ?? '').toString().toLowerCase() != 'listening') {
            continue;
          }
          final data = item['data'];
          if (data is Map) {
            script = (data['audio_text'] ?? data['script'] ?? '').toString();
            locale = (data['voice'] ?? data['locale'] ?? locale).toString();
          }
          if (script.trim().isNotEmpty) break;
        }
      }
    }
    return ListeningQuestionData(
      script: sanitizeScript(script),
      voiceLocale: normalizeLocale(locale),
    );
  }

  /// TTS 只接收自然语言；移除模型偶尔附带的 Markdown、代码围栏和
  /// JSON 结构字符，同时保留英文缩写、数字、日期和正常标点。
  static String sanitizeScript(String raw) {
    var value = raw.trim();
    value = value.replaceAll(
      RegExp(r'```(?:json|text)?', caseSensitive: false),
      '',
    );
    value = value.replaceAll('```', '');
    value = value.replaceAll(RegExp(r'\*\*|__|#{1,6}\s*|`'), '');
    value = value.replaceAll(
      RegExp(r'^\s*listening[_ ]?script\s*[:：]\s*', caseSensitive: false),
      '',
    );
    value = value.replaceAll(RegExp(r'[\[\]{}]'), ' ');
    value = value.replaceAll(RegExp(r'\\[nrt]'), ' ');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  static String normalizeLocale(String raw) {
    final locale = raw.trim().replaceAll('_', '-').toLowerCase();
    if (locale.startsWith('en-gb')) return 'en-GB';
    if (locale.startsWith('en')) return 'en-US';
    if (locale.startsWith('zh')) return 'zh-CN';
    return 'en-US';
  }

  static bool exposesAnswer({
    required String script,
    required Object? answer,
    List<String> options = const [],
  }) {
    final normalizedScript = script.toLowerCase();
    final answerText = answer?.toString().trim().toLowerCase() ?? '';
    if (answerText.isEmpty) return false;
    if (RegExp(r'^[a-d]$').hasMatch(answerText)) {
      return RegExp(
        'correct\\s+answer\\s+(?:is|:)\\s*$answerText|答案\\s*(?:是|为|:)\\s*$answerText',
        caseSensitive: false,
      ).hasMatch(normalizedScript);
    }
    if (answerText.length >= 3 && normalizedScript.contains(answerText)) {
      return RegExp(
        r'correct answer|答案是|答案为',
        caseSensitive: false,
      ).hasMatch(normalizedScript);
    }
    return false;
  }
}
