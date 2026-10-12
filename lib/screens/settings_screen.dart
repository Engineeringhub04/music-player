import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';

/// Server config, quality, network, theme, storage info, connection test.
class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  final StorageService storage;
  final VoidCallback onChanged;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.storage,
    required this.onChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;
  String _storagePath = '...';

  static const _qualities = [
    'Best',
    '2160p',
    '1440p',
    '1080p',
    '720p',
    '480p',
    '360p',
  ];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.settings.baseUrl);
    _keyController = TextEditingController(text: widget.settings.apiKey);
    _loadStoragePath();
  }

  Future<void> _loadStoragePath() async {
    final p = await widget.storage.downloadDirDisplayPath();
    if (mounted) setState(() => _storagePath = p);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveServer() async {
    await widget.settings.setBaseUrl(_urlController.text);
    await widget.settings.setApiKey(_keyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server settings saved.')),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final client = ApiClient(
        baseUrl: _urlController.text.trim().isEmpty
            ? SettingsService.defaultBaseUrl
            : _urlController.text.trim(),
        apiKey: _keyController.text.trim().isEmpty
            ? SettingsService.defaultApiKey
            : _keyController.text.trim(),
      );
      final items = await client.trending();
      if (!mounted) return;
      setState(() {
        _testOk = true;
        _testResult =
            'OK — server reachable, ${items.length} trending items.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testResult = 'Failed: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testResult = 'Failed: $e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Section('Extractor server'),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server base URL',
              hintText: 'http://127.0.0.1:8001',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API key',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: 'Save',
                  icon: Icons.save_outlined,
                  compact: true,
                  onPressed: _saveServer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.violet,
                          ),
                        )
                      : const Icon(Icons.wifi_find_outlined, size: 18),
                  label: const Text('Test connection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.violet),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testOk ? Colors.green : Colors.redAccent)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testOk ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _Section('Downloads'),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.high_quality_outlined,
            title: 'Default quality',
            trailing: DropdownButton<String>(
              value: _qualities.contains(s.defaultQuality)
                  ? s.defaultQuality
                  : 'Best',
              dropdownColor: AppTheme.cardDark,
              underline: const SizedBox(),
              items: _qualities
                  .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await s.setDefaultQuality(v);
                setState(() {});
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_outlined),
            title: const Text('Download on Wi-Fi only'),
            value: s.wifiOnly,
            activeThumbColor: AppTheme.violet,
            onChanged: (v) async {
              await s.setWifiOnly(v);
              setState(() {});
            },
          ),
          _tile(
            icon: Icons.folder_outlined,
            title: 'Download location',
            subtitle: _storagePath,
          ),
          const SizedBox(height: 24),
          const _Section('Appearance'),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'dark',
                  icon: Icon(Icons.dark_mode, size: 18),
                ),
                ButtonSegment(
                  value: 'light',
                  icon: Icon(Icons.light_mode, size: 18),
                ),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (sel) async {
                await s.setThemeMode(sel.first);
                widget.onChanged();
                setState(() {});
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppTheme.violet.withValues(alpha: 0.25)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Music Player v1.0.0+1\nPersonal use only',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.violet),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
              ),
            ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textGrey,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      );
}
