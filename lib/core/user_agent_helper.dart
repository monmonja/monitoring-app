import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserAgentModel {
  final String name;
  final String value;

  UserAgentModel({required this.name, required this.value});

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
      };

  factory UserAgentModel.fromJson(Map<String, dynamic> json) => UserAgentModel(
        name: json['name'],
        value: json['value'],
      );
}

class UserAgentHelper {
  static const String _prefsKey = 'custom_user_agents';

  static final List<UserAgentModel> defaultAgents = [
    UserAgentModel(
      name: 'Windows 11 - Chrome',
      value: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
    ),
    UserAgentModel(
      name: 'Windows 11 - Edge',
      value: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0',
    ),
    UserAgentModel(
      name: 'macOS - Safari',
      value: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3.1 Safari/605.1.15',
    ),
    UserAgentModel(
      name: 'macOS - Chrome',
      value: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
    ),
    UserAgentModel(
      name: 'Linux - Firefox',
      value: 'Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0',
    ),
    UserAgentModel(
      name: 'Linux - Chrome',
      value: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
    ),
    UserAgentModel(
      name: 'iOS - Safari (iPhone 16 Pro)',
      value: 'Mozilla/5.0 (iPhone17,1; CPU iPhone OS 18_2_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    ),
    UserAgentModel(
      name: 'iOS - Chrome (iPhone 16)',
      value: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/134.0.6367.111 Mobile/15E148 Safari/604.1',
    ),
    UserAgentModel(
      name: 'Android - Chrome (Pixel 9 Pro)',
      value: 'Mozilla/5.0 (Linux; Android 14; Pixel 9 Pro Build/AD1A.240418.003; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/124.0.6367.54 Mobile Safari/537.36',
    ),
    UserAgentModel(
      name: 'Android - Firefox (Galaxy Xcover7)',
      value: 'Mozilla/5.0 (Android 15; Mobile; SM-G556B; rv:130.0) Gecko/130.0 Firefox/130.0',
    ),
  ];

  static Future<List<UserAgentModel>> getUserAgents() async {
    final prefs = await SharedPreferences.getInstance();
    final agentsStr = prefs.getString(_prefsKey);

    if (agentsStr == null) {
      // First time, save and return defaults
      await saveUserAgents(defaultAgents);
      return defaultAgents;
    }

    try {
      final List<dynamic> decoded = jsonDecode(agentsStr);
      return decoded.map((e) => UserAgentModel.fromJson(e)).toList();
    } catch (e) {
      return defaultAgents;
    }
  }

  static Future<void> saveUserAgents(List<UserAgentModel> agents) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = agents.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  static Future<void> addAgent(UserAgentModel agent) async {
    final agents = await getUserAgents();
    agents.add(agent);
    await saveUserAgents(agents);
  }

  static Future<void> deleteAgent(int index) async {
    final agents = await getUserAgents();
    if (index >= 0 && index < agents.length) {
      agents.removeAt(index);
      await saveUserAgents(agents);
    }
  }
}
