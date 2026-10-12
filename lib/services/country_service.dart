import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

/// IP-based country detection (cached). Uses the free ipapi.co endpoint;
/// falls back to ip-api.com. Never throws — returns null when offline.
class CountryService {

  /// Detect the country from the device IP and persist it in [settings].
  /// Returns the ISO code, or null when detection failed.
  static Future<String?> detectAndSave(SettingsService settings) async {
    final code = await detect();
    if (code == null) return null;
    await settings.setCountry(code, nameFor(code));
    return code;
  }

  /// Raw detection without saving.
  static Future<String?> detect() async {
    // ipapi.co: HTTPS, free ~1k req/day.
    try {
      final resp = await http
          .get(Uri.parse('https://ipapi.co/country/'))
          .timeout(const Duration(seconds: 10));
      final code = resp.body.trim().toUpperCase();
      if (resp.statusCode == 200 && RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
        return code;
      }
    } catch (_) {}
    // Fallback: ip-api.com JSON.
    try {
      final resp = await http
          .get(Uri.parse('http://ip-api.com/json/?fields=countryCode'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final code =
            (decoded['countryCode'] ?? '').toString().toUpperCase();
        if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) return code;
      }
    } catch (_) {}
    return null;
  }

  /// Regional-indicator flag emoji for an ISO code, e.g. "NP" -> 🇳🇵.
  static String flagFor(String code) {
    final c = code.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(c)) return '🌐';
    return String.fromCharCodes(
      c.runes.map((r) => 0x1F1E6 + r - 0x41),
    );
  }

  /// English country name for an ISO code (common countries; else the code).
  static String nameFor(String code) =>
      _names[code.toUpperCase()] ?? code.toUpperCase();

  /// All known code -> name entries, sorted with Nepal first.
  static List<MapEntry<String, String>> get all {
    final entries = _names.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  static const Map<String, String> _names = {
    'NP': 'Nepal',
    'IN': 'India',
    'US': 'United States',
    'GB': 'United Kingdom',
    'AU': 'Australia',
    'CA': 'Canada',
    'DE': 'Germany',
    'FR': 'France',
    'JP': 'Japan',
    'KR': 'South Korea',
    'CN': 'China',
    'AE': 'UAE',
    'SA': 'Saudi Arabia',
    'QA': 'Qatar',
    'MY': 'Malaysia',
    'SG': 'Singapore',
    'TH': 'Thailand',
    'PK': 'Pakistan',
    'BD': 'Bangladesh',
    'LK': 'Sri Lanka',
    'BT': 'Bhutan',
    'MV': 'Maldives',
    'AF': 'Afghanistan',
    'MM': 'Myanmar',
    'ID': 'Indonesia',
    'PH': 'Philippines',
    'VN': 'Vietnam',
    'NZ': 'New Zealand',
    'IT': 'Italy',
    'ES': 'Spain',
    'PT': 'Portugal',
    'NL': 'Netherlands',
    'BE': 'Belgium',
    'CH': 'Switzerland',
    'AT': 'Austria',
    'SE': 'Sweden',
    'NO': 'Norway',
    'DK': 'Denmark',
    'FI': 'Finland',
    'IE': 'Ireland',
    'PL': 'Poland',
    'RU': 'Russia',
    'UA': 'Ukraine',
    'TR': 'Turkey',
    'IL': 'Israel',
    'EG': 'Egypt',
    'ZA': 'South Africa',
    'NG': 'Nigeria',
    'KE': 'Kenya',
    'BR': 'Brazil',
    'MX': 'Mexico',
    'AR': 'Argentina',
    'CL': 'Chile',
    'CO': 'Colombia',
    'HK': 'Hong Kong',
    'TW': 'Taiwan',
    'BH': 'Bahrain',
    'KW': 'Kuwait',
    'OM': 'Oman',
    'JO': 'Jordan',
    'LB': 'Lebanon',
    'IQ': 'Iraq',
    'IR': 'Iran',
  };
}
