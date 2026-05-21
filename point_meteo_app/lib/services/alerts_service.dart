import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/alert_rule.dart';
import 'notification_service.dart';

class AlertsService {
  static const String _rulesKey = 'smart_alert_rules';
  static const String _backendUrlKey = 'alerts_backend_url';

  // URL du backend smart-alerts déployé (à configurer après déploiement)
  static const String defaultBackendUrl = 'https://point-meteo.onrender.com';

  static Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendUrlKey) ?? defaultBackendUrl;
  }

  static Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url);
  }

  static Future<List<AlertRule>> getRules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_rulesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      return AlertRule.listFromJson(jsonStr);
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveRules(List<AlertRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rulesKey, AlertRule.listToJson(rules));
    await _syncWithBackend(rules);
  }

  static Future<void> addRule(AlertRule rule) async {
    final rules = await getRules();
    rules.add(rule);
    await _saveRules(rules);
  }

  static Future<void> deleteRule(String id) async {
    final rules = await getRules();
    rules.removeWhere((r) => r.id == id);
    await _saveRules(rules);
  }

  static Future<void> toggleRule(String id) async {
    final rules = await getRules();
    final idx = rules.indexWhere((r) => r.id == id);
    if (idx != -1) {
      rules[idx].isEnabled = !rules[idx].isEnabled;
    }
    await _saveRules(rules);
  }

  static Future<void> _syncWithBackend(List<AlertRule> rules) async {
    final token = NotificationService.fcmToken;
    if (token == null) return;

    try {
      final backendUrl = await getBackendUrl();
      await http
          .post(
            Uri.parse('$backendUrl/devices/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'fcmToken': token,
              'rules': rules.where((r) => r.isEnabled).map((r) => r.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Sync échoue silencieusement si le backend n'est pas configuré
    }
  }

  static String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}
