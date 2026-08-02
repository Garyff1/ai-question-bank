import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../storage/secure_api_config_storage.dart';
import 'api_key_masking.dart';

class ApiKeySecurityAuditResult {
  const ApiKeySecurityAuditResult({
    required this.secureStorageAvailable,
    required this.apiKeyConfigured,
    required this.maskedKey,
    required this.plaintextLegacyFieldFound,
  });

  final bool secureStorageAvailable;
  final bool apiKeyConfigured;
  final String maskedKey;
  final bool plaintextLegacyFieldFound;
}

class ApiKeySecurityAudit {
  const ApiKeySecurityAudit(this.storage);
  final SecureApiConfigStorage storage;

  Future<ApiKeySecurityAuditResult> run({
    required String legacyPreferencesKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var plaintextFound = false;
    final raw = prefs.getString(legacyPreferencesKey);
    try {
      final decoded = raw == null ? null : jsonDecode(raw);
      plaintextFound = decoded is Map && decoded.containsKey('apiKey');
    } catch (_) {}
    try {
      final key = (await storage.readApiKey() ?? '').trim();
      return ApiKeySecurityAuditResult(
        secureStorageAvailable: true,
        apiKeyConfigured: key.isNotEmpty,
        maskedKey: maskApiKey(key),
        plaintextLegacyFieldFound: plaintextFound,
      );
    } catch (_) {
      return ApiKeySecurityAuditResult(
        secureStorageAvailable: false,
        apiKeyConfigured: false,
        maskedKey: '',
        plaintextLegacyFieldFound: plaintextFound,
      );
    }
  }
}
