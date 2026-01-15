import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/models.dart';

/// Service for persisting configuration data to local storage.
/// Ready to be replaced with backend API in the future.
abstract class ConfigurationStorageService {
  Future<NavigationConfig?> loadConfiguration();
  Future<void> saveConfiguration(NavigationConfig config);
  Future<void> deleteConfiguration();
  Future<List<String>> listConfigurations();
  Future<NavigationConfig?> loadConfigurationById(String id);
}

class LocalConfigurationStorageService implements ConfigurationStorageService {
  static const String _configKey = 'navigation_config';
  static const String _configListKey = 'navigation_config_list';

  @override
  Future<NavigationConfig?> loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_configKey);
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return NavigationConfig.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveConfiguration(NavigationConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config.toJson());
    await prefs.setString(_configKey, jsonString);
    
    // Also save to config list
    await _addToConfigList(config.id);
  }

  @override
  Future<void> deleteConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
  }

  @override
  Future<List<String>> listConfigurations() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_configListKey) ?? [];
  }

  @override
  Future<NavigationConfig?> loadConfigurationById(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('${_configKey}_$id');
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return NavigationConfig.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> _addToConfigList(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_configListKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_configListKey, list);
    }
  }
}
