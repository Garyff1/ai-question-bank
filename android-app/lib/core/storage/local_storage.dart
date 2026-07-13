import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 的轻量封装。
///
/// v3 先统一新设置的读写入口，旧业务数据键继续由原模块管理，避免一次性迁移风险。
class LocalStorage {
  LocalStorage(this._preferences);

  final SharedPreferences _preferences;

  static Future<LocalStorage> create() async {
    return LocalStorage(await SharedPreferences.getInstance());
  }

  String? getString(String key) => _preferences.getString(key);
  bool? getBool(String key) => _preferences.getBool(key);

  Future<bool> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  Future<bool> setBool(String key, bool value) {
    return _preferences.setBool(key, value);
  }
}
