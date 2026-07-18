import 'dart:convert';

import 'package:ai_question_bank_android/core/storage/secure_api_config_storage.dart';
import 'package:ai_question_bank_android/features/official_ai/official_ai_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestSecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

http.Response jsonResponse(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('feature flags keep real charge disabled', () async {
    final client = await OfficialAiClient.create(
      secureStorage: SecureApiConfigStorage(secureStore: TestSecureStore()),
      httpClient: MockClient(
        (_) async => jsonResponse({
          'officialAiEnabled': true,
          'shadowBillingEnabled': true,
          'paymentMockEnabled': true,
          'wechatPayEnabled': false,
          'alipayPayEnabled': false,
          'realChargeEnabled': false,
          'environment': 'test',
        }),
      ),
    );
    final flags = await client.features();
    expect(flags.paymentMockEnabled, isTrue);
    expect(flags.realChargeEnabled, isFalse);
    expect(flags.wechatPayEnabled, isFalse);
  });

  test(
    'login token is stored securely and used for account requests',
    () async {
      final secure = TestSecureStore();
      final httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/login')) {
          expect(request.headers['authorization'], isNull);
          return jsonResponse({'access_token': 'safe-test-token'});
        }
        expect(request.headers['authorization'], 'Bearer safe-test-token');
        return jsonResponse({'items': []});
      });
      final client = await OfficialAiClient.create(
        secureStorage: SecureApiConfigStorage(secureStore: secure),
        httpClient: httpClient,
      );
      await client.login('test@example.com', 'password');
      await client.orders();
      expect(
        secure.values[SecureApiConfigStorage.officialTokenStorageKey],
        'safe-test-token',
      );
    },
  );

  test('quote parses integer fen and free local capabilities', () async {
    final secure = TestSecureStore()
      ..values[SecureApiConfigStorage.officialTokenStorageKey] = 'token';
    final client = await OfficialAiClient.create(
      secureStorage: SecureApiConfigStorage(secureStore: secure),
      httpClient: MockClient(
        (_) async => jsonResponse({
          'quoteId': 'quote-1',
          'questionCount': 5,
          'amountFen': 50,
          'currency': 'CNY',
          'breakdown': [
            {
              'code': 'ordinary_questions',
              'labelZh': '普通题目：5题',
              'labelEn': 'Ordinary questions: 5',
              'amountFen': 50,
              'free': false,
            },
            {
              'code': 'local_ocr',
              'labelZh': '本地OCR',
              'labelEn': 'Local OCR',
              'amountFen': 0,
              'free': true,
            },
          ],
          'expiresAt': '2026-07-17T12:00:00Z',
        }),
      ),
    );
    final quote = await client.quote(5);
    expect(quote.amountFen, 50);
    expect(quote.items.last.free, isTrue);
  });

  test('401 clears only official token', () async {
    final secure = TestSecureStore()
      ..values[SecureApiConfigStorage.officialTokenStorageKey] = 'expired'
      ..values[SecureApiConfigStorage.apiKeyStorageKey] = 'sk-personal';
    final client = await OfficialAiClient.create(
      secureStorage: SecureApiConfigStorage(secureStore: secure),
      httpClient: MockClient(
        (_) async => jsonResponse({'detail': 'invalid'}, status: 401),
      ),
    );
    await expectLater(client.orders(), throwsA(isA<OfficialAiException>()));
    expect(
      secure.values[SecureApiConfigStorage.officialTokenStorageKey],
      isNull,
    );
    expect(
      secure.values[SecureApiConfigStorage.apiKeyStorageKey],
      'sk-personal',
    );
  });
}
