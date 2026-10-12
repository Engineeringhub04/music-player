import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/main.dart';
import 'package:music_player/services/download_manager.dart';
import 'package:music_player/services/history_service.dart';
import 'package:music_player/services/library_service.dart';
import 'package:music_player/services/player_service.dart';
import 'package:music_player/services/settings_service.dart';
import 'package:music_player/services/storage_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App root builds with 5-tab bottom navigation',
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
    final library = LibraryService();
    final player = PlayerService(settings: settings);

    await tester.pumpWidget(
      MusicPlayerApp(
        settings: settings,
        downloads: downloads,
        storage: storage,
        history: history,
        library: library,
        player: player,
      ),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Discover Great Music'), findsOneWidget);
  });
}
