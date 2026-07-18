import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/secure_api_config_storage.dart';
import 'official_ai_models.dart';

class OfficialAiException implements Exception {
  const OfficialAiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class OfficialAiClient {
  OfficialAiClient._({
    required this.baseUrl,
    required SecureApiConfigStorage secureStorage,
    required SharedPreferences preferences,
    required http.Client httpClient,
    String? token,
  }) : _secureStorage = secureStorage,
       _preferences = preferences,
       _http = httpClient,
       _token = token;

  static const defaultBaseUrl = 'http://10.0.2.2:8000';

  String baseUrl;
  final SecureApiConfigStorage _secureStorage;
  final SharedPreferences _preferences;
  final http.Client _http;
  String? _token;

  bool get signedIn => _token != null && _token!.isNotEmpty;

  static Future<OfficialAiClient> create({
    SecureApiConfigStorage? secureStorage,
    SharedPreferences? preferences,
    http.Client? httpClient,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final secure = secureStorage ?? SecureApiConfigStorage();
    return OfficialAiClient._(
      baseUrl:
          prefs.getString(
            SecureApiConfigStorage.officialBaseUrlPreferencesKey,
          ) ??
          defaultBaseUrl,
      secureStorage: secure,
      preferences: prefs,
      httpClient: httpClient ?? http.Client(),
      token: await secure.readOfficialToken(),
    );
  }

  Future<void> updateBaseUrl(String value) async {
    baseUrl = value.trim().replaceAll(RegExp(r'/+$'), '');
    await _preferences.setString(
      SecureApiConfigStorage.officialBaseUrlPreferencesKey,
      baseUrl,
    );
  }

  Future<OfficialFeatureFlags> features() async =>
      OfficialFeatureFlags.fromJson(
        await _request(
          'GET',
          '/api/official-ai/features',
          authenticated: false,
        ),
      );

  Future<void> login(
    String email,
    String password, {
    bool register = false,
  }) async {
    final result = await _request(
      'POST',
      register ? '/api/auth/register' : '/api/auth/login',
      authenticated: false,
      body: {'email': email.trim(), 'password': password},
    );
    final token = result['access_token'] as String? ?? '';
    if (token.isEmpty) throw const OfficialAiException('服务器未返回登录凭据');
    await _secureStorage.saveOfficialToken(token);
    _token = token;
  }

  Future<void> logout() async {
    await _secureStorage.clearOfficialToken();
    _token = null;
  }

  Future<OfficialQuote> quote(int questionCount) async =>
      OfficialQuote.fromJson(
        await _request(
          'POST',
          '/api/official-ai/quotes',
          body: {
            'questionCount': questionCount,
            'serviceType': 'question_generation',
            'questionTypes': ['choice'],
            'addOns': <String>[],
          },
        ),
      );

  Future<OfficialOrder> createMockOrder(OfficialQuote quote) async {
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    return OfficialOrder.fromJson(
      await _request(
        'POST',
        '/api/official-ai/orders',
        body: {
          'quoteId': quote.id,
          'paymentChannel': 'mock',
          'clientRequestId': 'android-$nonce',
          'idempotencyKey': 'android-idempotency-$nonce',
        },
      ),
    );
  }

  Future<OfficialOrder> mockPay(
    String orderId, {
    String generationScenario = 'success',
    String refundOutcome = 'success',
  }) async => OfficialOrder.fromJson(
    await _request(
      'POST',
      '/api/official-ai/orders/$orderId/mock-pay',
      body: {
        'outcome': 'success',
        'generationScenario': generationScenario,
        'refundOutcome': refundOutcome,
      },
    ),
  );

  Future<OfficialOrder> order(String orderId) async => OfficialOrder.fromJson(
    await _request('GET', '/api/official-ai/orders/$orderId'),
  );

  Future<List<OfficialOrder>> orders() async {
    final result = await _request('GET', '/api/official-ai/orders');
    return (result['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => OfficialOrder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OfficialUsage>> usage() async {
    final result = await _request('GET', '/api/official-ai/usage');
    return (result['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => OfficialUsage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> deleteCloudData() async {
    await _request('DELETE', '/api/official-ai/data', allowEmpty: true);
  }

  Future<void> deleteAccount(String password) async {
    await _request(
      'DELETE',
      '/api/official-ai/account',
      body: {'password': password},
      allowEmpty: true,
    );
    await logout();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    bool authenticated = true,
    Map<String, dynamic>? body,
    bool allowEmpty = false,
  }) async {
    if (authenticated && !signedIn) {
      throw const OfficialAiException('请先登录官方 AI 服务');
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) headers['Authorization'] = 'Bearer $_token';
    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    try {
      response = switch (method) {
        'GET' => await _http.get(uri, headers: headers),
        'DELETE' => await _http.delete(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        _ => await _http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        ),
      };
    } catch (_) {
      throw const OfficialAiException('无法连接官方服务测试环境，请检查服务器地址和网络');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (allowEmpty || response.body.trim().isEmpty) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    }
    var message = '请求失败（${response.statusCode}）';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['detail'] is String) {
        message = decoded['detail'] as String;
      }
    } catch (_) {}
    if (response.statusCode == 401) {
      await logout();
      message = '登录已失效，请重新登录';
    }
    throw OfficialAiException(message, statusCode: response.statusCode);
  }
}
