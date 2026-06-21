import 'package:shared_preferences/shared_preferences.dart';

class AiConfig {
  static const _key = 'ai_proxy_base';

  /// Default base used for Android emulator. Override on device.
  /// Updated to the deployed Firebase Function URL so the app works on phone.
  static const defaultBase = 'https://us-central1-fish-app-release.cloudfunctions.net/api/v1/ai';

  static Future<String> getBase() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key) ?? defaultBase;
  }

  static Future<void> setBase(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, url);
  }
}
