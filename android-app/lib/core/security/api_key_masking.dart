String maskApiKey(String value, {int visibleSuffix = 4}) {
  final secret = value.trim();
  if (secret.isEmpty) return '';
  final suffixLength = visibleSuffix.clamp(0, secret.length);
  final suffix = secret.substring(secret.length - suffixLength);
  final prefix = secret.startsWith('sk-') ? 'sk-' : '';
  return '$prefix${'•' * 12}$suffix';
}

bool containsLikelySecret(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  return RegExp(
    r'(sk-[a-z0-9_-]{12,}|bearer\s+[a-z0-9._-]{12,}|api[-_ ]?key\s*[:=]\s*\S+)',
    caseSensitive: false,
  ).hasMatch(text);
}
