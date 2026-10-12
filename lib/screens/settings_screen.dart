import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../services/library_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';

/// Settings rows matching the reference layout.
/// Kept: Clear Cache, Media Quality, Theme, Restore/Backup Lists, Share App,
/// Rate Us, Privacy Policy, Terms of Use, Manage Privacy Settings.
/// Added: Server URL + API Key (extractor). Removed: Spotify, Login, Country.
class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  final StorageService storage;
  final LibraryService library;
  final VoidCallback onChanged;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.storage,
    required this.library,
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
  String _cacheSize = '...';

  static const _qualities = [
    'Best',
    '2160p',
    '1440p',
    '1080p',
    '720p',
    '480p',
    '360p',
    'Audio only',
  ];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.settings.baseUrl);
    _keyController = TextEditingController(text: widget.settings.apiKey);
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    try {
      final bytes = await widget.storage.totalBytes();
      if (mounted) setState(() => _cacheSize = _fmt(bytes));
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '—');
    }
  }

  String _fmt(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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

  void _editServerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(c).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Extractor Server', style: AppText.title),
              const SizedBox(height: 14),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Server base URL',
                  labelStyle: TextStyle(color: AppTheme.textGrey),
                  prefixIcon:
                      Icon(Icons.dns_outlined, color: AppTheme.textGrey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyController,
                obscureText: _obscureKey,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'API key',
                  labelStyle:
                      const TextStyle(color: AppTheme.textGrey),
                  prefixIcon: const Icon(Icons.key_outlined,
                      color: AppTheme.textGrey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppTheme.textGrey,
                    ),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: 'Save',
                      icon: Icons.save_outlined,
                      compact: true,
                      onPressed: () {
                        _saveServer();
                        Navigator.of(c).pop();
                      },
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
                          : const Icon(Icons.wifi_find_outlined,
                              size: 18),
                      label: const Text('Test'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side:
                            const BorderSide(color: AppTheme.violet),
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 10),
                Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testOk
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBlack,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Center(
                child: Text('Settings', style: AppText.pageTitle)),
            const SizedBox(height: 16),
            SettingsRow(
              icon: Icons.dns_outlined,
              title: 'Server URL',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      s.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppText.body,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textGrey),
                ],
              ),
              onTap: _editServerSheet,
            ),
            SettingsRow(
              icon: Icons.key_outlined,
              title: 'API Key',
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('••••••••', style: AppText.body),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      color: AppTheme.textGrey),
                ],
              ),
              onTap: _editServerSheet,
            ),
            SettingsRow(
              icon: Icons.close,
              title: 'Clear Cache',
              trailing: Text(
                _cacheSize,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              onTap: () async {
                await widget.library.clearCache();
                await _loadCacheSize();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Cache cleared.')),
                  );
                }
              },
            ),
            SettingsRow(
              icon: Icons.play_circle_outline,
              title: 'Media Quality',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.defaultQuality.toLowerCase(),
                    style: AppText.body,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.unfold_more,
                      color: AppTheme.textGrey, size: 20),
                ],
              ),
              onTap: () => _pickQuality(s),
            ),
            SettingsRow(
              icon: Icons.nightlight_round,
              title: 'Theme',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.themeMode == 'light'
                        ? 'light theme'
                        : 'dark theme',
                    style: AppText.body,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.unfold_more,
                      color: AppTheme.textGrey, size: 20),
                ],
              ),
              onTap: () async {
                final next =
                    s.themeMode == 'light' ? 'dark' : 'light';
                await s.setThemeMode(next);
                widget.onChanged();
                setState(() {});
              },
            ),
            SettingsRow(
              icon: Icons.playlist_add,
              title: 'Restore Lists',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Restore: paste a backup via Backup Lists export.'),
                  ),
                );
              },
            ),
            SettingsRow(
              icon: Icons.upload_outlined,
              title: 'Backup Lists',
              onTap: () async {
                final json = await widget.library.exportJson();
                await SharePlus.instance.share(
                  ShareParams(text: json, subject: 'Music Player backup'),
                );
              },
            ),
            SettingsRow(
              icon: Icons.upload_outlined,
              title: 'Share App',
              onTap: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Music Player — personal music app',
                  ),
                );
              },
            ),
            SettingsRow(
              icon: Icons.star,
              title: 'Rate Us',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Thanks for using Music Player!')),
                );
              },
            ),
            SettingsRow(
              icon: Icons.lock_outline,
              title: 'Privacy Policy',
              onTap: () => _showDoc(
                  'Privacy Policy',
                  'Music Player stores all data locally on your device. '
                      'No account, no tracking, no analytics. Downloads stay in your '
                      'MusicPlayer folder.'),
            ),
            SettingsRow(
              icon: Icons.description_outlined,
              title: 'Terms of Use',
              onTap: () => _showDoc(
                  'Terms of Use',
                  'Personal use only. Only download content you have the right to. '
                      'Respect creators and copyright law.'),
            ),
            SettingsRow(
              icon: Icons.tune_outlined,
              title: 'Manage Privacy Settings',
              onTap: () => _showDoc(
                  'Privacy Settings',
                  'There is nothing to manage — the app collects no data.'),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Music Player v1.0.0+1\nPersonal use only',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textGrey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickQuality(SettingsService s) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Media Quality', style: AppText.title),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _qualities.length,
                itemBuilder: (c, i) {
                  final q = _qualities[i];
                  final selected = s.defaultQuality == q;
                  return ListTile(
                    title: Text(
                      q,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check,
                            color: AppTheme.violet)
                        : null,
                    onTap: () async {
                      await s.setDefaultQuality(q);
                      if (c.mounted) Navigator.of(c).pop();
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDoc(String title, String body) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white),
        ),
        content: Text(body, style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: AppTheme.violet),
            ),
          ),
        ],
      ),
    );
  }
}
