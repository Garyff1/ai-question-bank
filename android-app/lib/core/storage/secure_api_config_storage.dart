import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SecureApiConfigResult {
  const SecureApiConfigResult({
    required this.metadata,
    required this.apiKey,
    required this.migrated,
    required this.migrationFailed,
  });

  final Map<String, dynamic> metadata;
  final String apiKey;
  final bool migrated;
  final bool migrationFailed;
}

class SecureApiConfigStorage {
  SecureApiConfigStorage({SecureKeyValueStore? secureStore})
    : _secure = secureStore ?? FlutterSecureKeyValueStore();

  static const apiKeyStorageKey = 'secure.api_key_v3';
  static const officialTokenStorageKey = 'secure.official_token_v3';
  static const serviceModePreferencesKey = 'ai_service_mode_v3';
  static const officialBaseUrlPreferencesKey = 'official_ai_base_url_v3';

  final SecureKeyValueStore _secure;

  Future<SecureApiConfigResult> loadAndMigrate({
    required SharedPreferences preferences,
    required String legacyPreferencesKey,
  }) async {
    final raw = preferences.getString(legacyPreferencesKey);
    Map<String, dynamic> metadata = <String, dynamic>{};
    try {
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is Map) metadata = Map<String, dynamic>.from(decoded);
    } catch (_) {
      metadata = <String, dynamic>{};
    }

    final legacyApiKey = (metadata['apiKey'] as String? ?? '').trim();
    String secureApiKey = '';
    try {
      secureApiKey = (await _secure.read(apiKeyStorageKey) ?? '').trim();
    } catch (_) {
      return SecureApiConfigResult(
        metadata: metadata,
        apiKey: legacyApiKey,
        migrated: false,
        migrationFailed: legacyApiKey.isNotEmpty,
      );
    }

    var migrated = false;
    if (secureApiKey.isEmpty && legacyApiKey.isNotEmpty) {
      try {
        await _secure.write(apiKeyStorageKey, legacyApiKey);
        final verified = (await _secure.read(apiKeyStorageKey) ?? '').trim();
        if (verified != legacyApiKey) {
          throw StateError('Secure API Key verification failed');
        }
        secureApiKey = verified;
        migrated = true;
      } catch (_) {
        return SecureApiConfigResult(
          metadata: metadata,
          apiKey: legacyApiKey,
          migrated: false,
          migrationFailed: true,
        );
      }
    }

    // Remove plaintext only after a secure value has been read back successfully.
    if (secureApiKey.isNotEmpty && metadata.containsKey('apiKey')) {
      final sanitized = Map<String, dynamic>.from(metadata)..remove('apiKey');
      final persisted = await preferences.setString(
        legacyPreferencesKey,
        jsonEncode(sanitized),
      );
      if (persisted) metadata = sanitized;
    }
    return SecureApiConfigResult(
      metadata: metadata,
      apiKey: secureApiKey,
      migrated: migrated,
      migrationFailed: false,
    );
  }

  Future<void> save({
    required SharedPreferences preferences,
    required String preferencesKey,
    required Map<String, dynamic> metadata,
    required String apiKey,
  }) async {
    final previousSecret = await _secure.read(apiKeyStorageKey);
    final previousMetadata = preferences.getString(preferencesKey);
    try {
      final trimmed = apiKey.trim();
      if (trimmed.isEmpty) {
        await _secure.delete(apiKeyStorageKey);
      } else {
        await _secure.write(apiKeyStorageKey, trimmed);
        final verified = await _secure.read(apiKeyStorageKey);
        if (verified != trimmed) {
          throw StateError('Secure API Key verification failed');
        }
      }
      final sanitized = Map<String, dynamic>.from(metadata)..remove('apiKey');
      final saved = await preferences.setString(
        preferencesKey,
        jsonEncode(sanitized),
      );
      if (!saved) throw StateError('API config metadata could not be saved');
    } catch (_) {
      if (previousSecret == null || previousSecret.isEmpty) {
        await _secure.delete(apiKeyStorageKey);
      } else {
        await _secure.write(apiKeyStorageKey, previousSecret);
      }
      if (previousMetadata == null) {
        await preferences.remove(preferencesKey);
      } else {
        await preferences.setString(preferencesKey, previousMetadata);
      }
      rethrow;
    }
  }

  Future<void> deleteApiConfig({
    required SharedPreferences preferences,
    required String preferencesKey,
  }) async {
    await _secure.delete(apiKeyStorageKey);
    await preferences.remove(preferencesKey);
  }

  Future<String?> readOfficialToken() => _secure.read(officialTokenStorageKey);

  Future<void> saveOfficialToken(String token) async {
    await _secure.write(officialTokenStorageKey, token);
    if (await _secure.read(officialTokenStorageKey) != token) {
      throw StateError('Official service token verification failed');
    }
  }

  Future<void> clearOfficialToken() => _secure.delete(officialTokenStorageKey);
}
