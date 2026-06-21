import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:login_fish_app/config/ai_config.dart';

class AiService {
  static String? _overrideBase;

  static Future<void> setBase(String url) async {
    _overrideBase = url;
    await AiConfig.setBase(url);
  }

  static Future<String> _base() async {
    if (_overrideBase != null) return _overrideBase!;
    return await AiConfig.getBase();
  }

  static Future<String> ask(String prompt) async {
    final base = await _base();
    final resp = await http.post(Uri.parse(base),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}));
    if (resp.statusCode != 200) throw Exception('AI error: ${resp.body}');
    final j = jsonDecode(resp.body);
    return j['text'] as String? ?? '';
  }

  static Future<String> speciesInfo(String species) async {
    final base = await _base();
    final resp = await http.post(Uri.parse(base),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'species': species}));
    if (resp.statusCode != 200) throw Exception('AI error: ${resp.body}');
    final j = jsonDecode(resp.body);
    return j['text'] as String? ?? '';
  }
}
