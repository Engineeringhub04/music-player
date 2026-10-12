import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/main.dart';
import 'package:music_player/services/download_manager.dart';
import 'package:music_player/services/history_service.dart';
import 'package:music_player/services/settings_service.dart';
import 'package:music_player/services/storage_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App root builds with bottom navigation',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    ReceiveSharingIntent.setMockValues(
      initialMedia: [],
      mediaStream: const Stream.empty(),
    );

    final settings = SettingsService();
    await settings.init();
    final downloads = DownloadManager();
    final storage = StorageService();
    final history = HistoryService();

    await tester.pumpWidget(
      MusicPlayerApp(
        settings: settings,
        downloads: downloads,
        storage: storage,
        history: history,
      ),
    );
    await tester.pump();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });
}
