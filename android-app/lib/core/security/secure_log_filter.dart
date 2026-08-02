String redactSensitiveText(Object? input) {
  var value = input?.toString() ?? '';
  value = value.replaceAll(
    RegExp(r'bearer\s+[a-z0-9._-]+', caseSensitive: false),
    'Bearer ***REDACTED***',
  );
  value = value.replaceAll(
    RegExp(
      r'(api[-_ ]?key|authorization|password|jwt)\s*[:=]\s*[^\s,}\]]+',
      caseSensitive: false,
    ),
    r'$1=***REDACTED***',
  );
  value = value.replaceAllMapped(
    RegExp(r'sk-[a-z0-9_-]{8,}', caseSensitive: false),
    (_) => 'sk-***REDACTED***',
  );
  return value;
}

String safeApiErrorMessage(Object error) {
  final redacted = redactSensitiveText(
    error,
  ).replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  final status = RegExp(r'\b([45]\d\d)\b').firstMatch(redacted)?.group(1);
  final lower = redacted.toLowerCase();
  if (status == '401' || status == '403') {
    return '连接失败（$status）\n请检查 API Key 是否正确、是否已失效或是否有模型权限。';
  }
  if (status == '429') {
    return '请求过于频繁（429）\n请检查账户余额或额度限制，稍后再试。';
  }
  if (lower.contains('handshake') || lower.contains('connection terminated')) {
    return '安全连接失败，请检查网络、VPN或系统时间后重试。';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return '连接超时，请检查网络后重试。';
  }
  return redacted.isEmpty ? '连接失败，请检查服务商配置后重试。' : redacted;
}
