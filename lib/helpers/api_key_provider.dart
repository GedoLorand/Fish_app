import 'package:flutter/services.dart';

class ApiKeyProvider {
  static const MethodChannel _chan = MethodChannel('ro.catchpoint/api');

  /// Returns the API key stored as meta-data in AndroidManifest (or null).
  static Future<String?> getApiKey() async {
    try {
      final res = await _chan.invokeMethod('getApiKey');
      if (res is String && res.isNotEmpty) return res;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns the Directions API key stored in manifest meta-data (or null).
  static Future<String?> getDirectionsApiKey() async {
    try {
      final res = await _chan.invokeMethod('getDirectionsApiKey');
      if (res is String && res.isNotEmpty) return res;
      return null;
    } catch (_) {
      return null;
    }
  }
}
