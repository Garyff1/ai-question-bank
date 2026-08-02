import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/secure_api_config_storage.dart';

enum AiServiceMode { byok, official }

extension AiServiceModeValue on AiServiceMode {
  String get storageValue =>
      this == AiServiceMode.official ? 'official' : 'byok';

  static AiServiceMode parse(String? value) =>
      value == 'official' ? AiServiceMode.official : AiServiceMode.byok;
}

class ServiceModeController {
  const ServiceModeController();

  Future<AiServiceMode> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AiServiceModeValue.parse(
      preferences.getString(SecureApiConfigStorage.serviceModePreferencesKey),
    );
  }

  Future<void> save(AiServiceMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      SecureApiConfigStorage.serviceModePreferencesKey,
      mode.storageValue,
    );
  }
}
