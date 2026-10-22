import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/hymn.dart';
import 'package:kairos_web/services/audio_service.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/hymns/hymn_detail_view.dart';
import 'package:kairos_web/views/hymns/widgets/hymn_audio_player_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> eventStreamControllers = {};
  final List<String> setSourceCalls = [];

  @override
  Future<void> create(String playerId) async {
    eventStreamControllers[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Future<void> dispose(String playerId) async {
    eventStreamControllers[playerId]?.close();
  }

  @override
  Future<void> stop(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<void> setAudioContext(String playerId, AudioContext audioContext) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<int?> getDuration(String playerId) async => 180000;

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<void> setSourceUrl(String playerId, String url, {bool? isLocal, String? mimeType}) async {
    setSourceCalls.add(url);
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes, {String? mimeType}) async {
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return eventStreamControllers
        .putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast())
        .stream;
  }
}

class FakeGlobalAudioplayersPlatform extends GlobalAudioplayersPlatformInterface {
  final StreamController<GlobalAudioEvent> _eventController =
      StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => _eventController.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioplayersPlatform fakePlatform;

  setUpAll(() {
    fakePlatform = FakeAudioplayersPlatform();
    AudioplayersPlatformInterface.instance = fakePlatform;
    GlobalAudioplayersPlatformInterface.instance = FakeGlobalAudioplayersPlatform();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakePlatform.setSourceCalls.clear();
    await AudioService().stop();
    AudioService().player.positionUpdater = null;
  });

  tearDown(() async {
    await AudioService().stop();
    AudioService().player.positionUpdater = null;
  });

  group('Native Audio Extraction & URL Validation (AudioService)', () {
    test('isYouTubeUrl detects valid YouTube formats correctly', () {
      expect(
        AudioService.isYouTubeUrl('https://www.youtube.com/watch?v=FDpludwY46U'),
        isTrue,
      );
      expect(
        AudioService.isYouTubeUrl('https://youtube.com/watch?v=FDpludwY46U'),
        isTrue,
      );
      expect(
        AudioService.isYouTubeUrl('https://youtu.be/FDpludwY46U'),
        isTrue,
      );
      expect(
        AudioService.isYouTubeUrl('http://m.youtube.com/watch?v=FDpludwY46U'),
        isTrue,
      );
      expect(
        AudioService.isYouTubeUrl('https://raw.githubusercontent.com/Lucas2Araujo/NHA_Intel/main/audio/cantado/hino_1.mp3'),
        isFalse,
      );
      expect(AudioService.isYouTubeUrl(''), isFalse);
      expect(AudioService.isYouTubeUrl(null), isFalse);
    });

    test('getDefaultAudioUrl returns correct GitHub raw endpoints', () {
      final cantadoUrl = AudioService.getDefaultAudioUrl(1, isInstrumental: false);
      expect(
        cantadoUrl,
        'https://raw.githubusercontent.com/Lucas2Araujo/NHA_Intel/main/audio/cantado/hino_1.mp3',
      );

      final instrumentalUrl = AudioService.getDefaultAudioUrl(1, isInstrumental: true);
      expect(
        instrumentalUrl,
        'https://raw.githubusercontent.com/Lucas2Araujo/NHA_Intel/main/audio/instrumental/hino_1.mp3',
      );
    });

    test('AudioService resolves YouTube stream URL and handles playback', () async {
      final audioService = AudioService();
      String? resolvedRequestedUrl;

      audioService.youtubeResolverOverride = (url) async {
        resolvedRequestedUrl = url;
        return 'https://googlevideo.com/videoplayback?id=mock_stream';
      };

      await audioService.playHymn(
        hymnId: 1,
        numero: '001',
        titulo: 'Santo, Santo, Santo!',
        customUrl: 'https://www.youtube.com/watch?v=FDpludwY46U',
      );

      expect(resolvedRequestedUrl, 'https://www.youtube.com/watch?v=FDpludwY46U');
      expect(audioService.currentHymnId, 1);
      expect(audioService.currentHymnNumber, '001');
      expect(audioService.currentHymnTitle, 'Santo, Santo, Santo!');
      expect(fakePlatform.setSourceCalls, contains('https://googlevideo.com/videoplayback?id=mock_stream'));
    });

    test('AudioService falls back to GitHub raw URL when YouTube extraction fails', () async {
      final audioService = AudioService();

      // Resolver returns null simulating network failure or blocked video
      audioService.youtubeResolverOverride = (url) async => null;

      await audioService.playHymn(
        hymnId: 42,
        numero: '042',
        titulo: 'Hino Teste Fallback',
        customUrl: 'https://www.youtube.com/watch?v=INVALID_VIDEO',
      );

      expect(audioService.currentHymnId, 42);
      expect(audioService.currentHymnNumber, '042');
      expect(
        fakePlatform.setSourceCalls,
        contains(AudioService.getDefaultAudioUrl(42, isInstrumental: false)),
      );
    });

    test('AudioService falls back to GitHub raw URL when no YouTube URL is provided', () async {
      final audioService = AudioService();
      audioService.youtubeResolverOverride = null;

      await audioService.playHymn(
        hymnId: 5,
        numero: '005',
        titulo: 'Jubilosos Te Adoramos',
      );

      expect(audioService.currentHymnId, 5);
      expect(audioService.currentHymnTitle, 'Jubilosos Te Adoramos');
      expect(
        fakePlatform.setSourceCalls,
        contains(AudioService.getDefaultAudioUrl(5, isInstrumental: false)),
      );
    });
  });

  group('HymnAudioPlayerWidget & HymnDetailView Integration', () {
    testWidgets('HymnAudioPlayerWidget accepts streamUrl parameter and renders properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HymnAudioPlayerWidget(
              numero: '001',
              titulo: 'Santo, Santo, Santo!',
              hymnId: 1,
              streamUrl: 'https://www.youtube.com/watch?v=FDpludwY46U',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hino 001 - Santo, Santo, Santo!'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('HymnDetailView passes linkVideo as streamUrl to HymnAudioPlayerWidget', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await ThemeService().init();

      const testHymn = Hymn(
        id: 1,
        numero: '001',
        titulo: 'Santo, Santo, Santo!',
        letra: 'Santo! Santo! Santo! Deus Onipotente!',
        linkVideo: 'https://www.youtube.com/watch?v=FDpludwY46U',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HymnDetailView(hymn: testHymn),
        ),
      );
      await tester.pump();

      // Open audio player panel by tapping "Áudio" button
      final audioButton = find.text('Áudio');
      expect(audioButton, findsOneWidget);
      await tester.tap(audioButton);
      await tester.pump(const Duration(milliseconds: 300));

      // Verify HymnAudioPlayerWidget was instantiated with streamUrl: linkVideo
      final playerFinder = find.byType(HymnAudioPlayerWidget);
      expect(playerFinder, findsOneWidget);

      final HymnAudioPlayerWidget playerWidget = tester.widget(playerFinder);
      expect(playerWidget.streamUrl, testHymn.linkVideo);
      expect(playerWidget.numero, '001');
      expect(playerWidget.hymnId, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
