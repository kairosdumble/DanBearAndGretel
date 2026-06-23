import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 시 발급된 JWT를 저장·조회합니다.
class AuthTokenStorage {
  static const _key = 'auth_access_token';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
