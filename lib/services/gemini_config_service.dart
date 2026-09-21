import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gemini_config.dart';

/// Central service managing Gemini AI transaction intelligence configuration.
class GeminiConfigService extends ChangeNotifier {
  static final GeminiConfigService _instance = GeminiConfigService._internal();
  factory GeminiConfigService() => _instance;
  GeminiConfigService._internal() {
    _loadFromPreferences();
  }

  static const String _prefKey = 'gemini_transaction_config';
  static const String _enabledKey = 'gemini_ai_enabled';

  GeminiConfig _config = const GeminiConfig();
  GeminiConfig get config => _config;
  bool get isEnabled => _config.enabled;

  // Diagnostic / telemetry counters for UI settings
  int _aiAssistedCount = 0;
  int _aiDecisionsCount = 0;
  int _pendingReviewCount = 0;

  int get aiAssistedCount => _aiAssistedCount;
  int get aiDecisionsCount => _aiDecisionsCount;
  int get pendingReviewCount => _pendingReviewCount;

  void incrementAiAssisted() {
    _aiAssistedCount++;
    notifyListeners();
  }

  void incrementAiDecisions() {
    _aiDecisionsCount++;
    notifyListeners();
  }

  void setPendingReviewCount(int count) {
    _pendingReviewCount = count;
    notifyListeners();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_enabledKey);
      final jsonStr = prefs.getString(_prefKey);

      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        _config = GeminiConfig.fromJson(decoded);
      } else if (enabled != null) {
        _config = _config.copyWith(enabled: enabled);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[GeminiConfigService] Error loading preferences: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _config = _config.copyWith(enabled: enabled);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
      await prefs.setString(_prefKey, jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('[GeminiConfigService] Error saving enabled state: $e');
    }
  }

  Future<void> updateConfig(GeminiConfig newConfig) async {
    _config = newConfig;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_config.toJson()));
      await prefs.setBool(_enabledKey, newConfig.enabled);
    } catch (e) {
      debugPrint('[GeminiConfigService] Error saving config: $e');
    }
  }

  @visibleForTesting
  void setConfigForTesting(GeminiConfig config) {
    _config = config;
    notifyListeners();
  }
}
