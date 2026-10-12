import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// App settings persisted in SharedPreferences.
/// Server base URL + API key default from --dart-define, overridable here.
class SettingsService {
  static const String _kBaseUrl = 'baseUrl';
  static const String _kApiKey = 'apiKey';
  static const String _kDefaultQuality = 'defaultQuality';
  static const String _kWifiOnly = 'wifiOnly';
  static const String _kThemeMode = 'themeMode';
  static const String _kCountryCode = 'countryCode';
  static const String _kCountryName = 'countryName';

  static const String defaultBaseUrl = String.fromEnvironment(
    'EXTRACTOR_BASE_URL',
    defaultValue: 'https://musicextractor.kishanraut.com.np',
  );
  static const String defaultApiKey = String.fromEnvironment(
    'EXTRACTOR_API_KEY',
    defaultValue: '61a475ed6ea9dd747092c8614a78744c',
  );

  late SharedPreferences _prefs;
  bool _ready = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ready = true;
  }

  bool get ready => _ready;

  String get baseUrl =>
      _prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
  Future<void> setBaseUrl(String v) => _prefs.setString(_kBaseUrl, v.trim());

  String get apiKey => _prefs.getString(_kApiKey) ?? defaultApiKey;
  Future<void> setApiKey(String v) => _prefs.setString(_kApiKey, v.trim());

  /// Preferred quality label, e.g. "720p", "Best", "Audio only".
  String get defaultQuality =>
      _prefs.getString(_kDefaultQuality) ?? 'Best';
  Future<void> setDefaultQuality(String v) =>
      _prefs.setString(_kDefaultQuality, v);

  bool get wifiOnly => _prefs.getBool(_kWifiOnly) ?? false;
  Future<void> setWifiOnly(bool v) => _prefs.setBool(_kWifiOnly, v);

  /// 'dark' or 'light'
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'dark';
  Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);

  /// ISO country code for country-based trending (e.g. "NP").
  String get countryCode => _prefs.getString(_kCountryCode) ?? '';
  String get countryName => _prefs.getString(_kCountryName) ?? '';
  Future<void> setCountry(String code, String name) async {
    await _prefs.setString(_kCountryCode, code.toUpperCase());
    await _prefs.setString(_kCountryName, name);
  }

  /// Fresh client built from the current settings.
  ApiClient get apiClient =>
      ApiClient(baseUrl: baseUrl, apiKey: apiKey);
}
