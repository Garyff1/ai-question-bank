import 'dart:convert';

import 'package:ai_question_bank_android/core/storage/secure_api_config_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  bool failWrites = false;
  bool corruptNextWrite = false;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('write failed');
    values[key] = corruptNextWrite ? '$value-corrupt' : value;
    corruptNextWrite = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('migrates plaintext key only after secure read-back succeeds', () async {
    SharedPreferences.setMockInitialValues({
      'api_config_v1': jsonEncode({
        'provider': 'deepseek',
        'apiKey': 'sk-legacy-secret',
        'baseUrl': 'https://api.deepseek.com',
        'model': 'deepseek-chat',
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final memory = MemorySecureStore();
    final storage = SecureApiConfigStorage(secureStore: memory);

    final result = await storage.loadAndMigrate(
      preferences: prefs,
      legacyPreferencesKey: 'api_config_v1',
    );

    expect(result.migrated, isTrue);
    expect(result.apiKey, 'sk-legacy-secret');
    expect(
      memory.values[SecureApiConfigStorage.apiKeyStorageKey],
      'sk-legacy-secret',
    );
    expect(
      prefs.getString('api_config_v1'),
      isNot(contains('sk-legacy-secret')),
    );
    expect(result.metadata.containsKey('apiKey'), isFalse);
  });

  test('migration failure preserves legacy plaintext for recovery', () async {
    SharedPreferences.setMockInitialValues({
      'api_config_v1': jsonEncode({
        'apiKey': 'sk-do-not-lose',
        'provider': 'custom',
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final memory = MemorySecureStore()..failWrites = true;
    final storage = SecureApiConfigStorage(secureStore: memory);

    final result = await storage.loadAndMigrate(
      preferences: prefs,
      legacyPreferencesKey: 'api_config_v1',
    );

    expect(result.migrationFailed, isTrue);
    expect(result.apiKey, 'sk-do-not-lose');
    expect(prefs.getString('api_config_v1'), contains('sk-do-not-lose'));
  });

  test('save rolls back secret and metadata when verification fails', () async {
    SharedPreferences.setMockInitialValues({
      'api_config_v1': jsonEncode({'provider': 'deepseek'}),
    });
    final prefs = await SharedPreferences.getInstance();
    final memory = MemorySecureStore()
      ..values[SecureApiConfigStorage.apiKeyStorageKey] = 'sk-old';
    final storage = SecureApiConfigStorage(secureStore: memory);
    memory.corruptNextWrite = true;

    await expectLater(
      storage.save(
        preferences: prefs,
        preferencesKey: 'api_config_v1',
        metadata: {'provider': 'qwen'},
        apiKey: 'sk-new',
      ),
      throwsStateError,
    );
    expect(memory.values[SecureApiConfigStorage.apiKeyStorageKey], 'sk-old');
    expect(
      jsonDecode(prefs.getString('api_config_v1')!)['provider'],
      'deepseek',
    );
  });

  test('official logout does not remove personal API key', () async {
    final memory = MemorySecureStore()
      ..values[SecureApiConfigStorage.apiKeyStorageKey] = 'sk-personal';
    final storage = SecureApiConfigStorage(secureStore: memory);
    await storage.saveOfficialToken('official-token');
    await storage.clearOfficialToken();
    expect(await storage.readOfficialToken(), isNull);
    expect(
      memory.values[SecureApiConfigStorage.apiKeyStorageKey],
      'sk-personal',
    );
  });
}
