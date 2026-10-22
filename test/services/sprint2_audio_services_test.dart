import 'dart:async';
// ignore: depend_on_referenced_packages
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kairos_web/services/audio_service.dart';
import 'package:kairos_web/services/wallpaper_service.dart';
import 'package:kairos_web/services/gamification_service.dart';

class _FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> eventStreamControllers = {};

  @override
  Future<void> create(String playerId) async {
    eventStreamControllers[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Future<void> dispose(String playerId) async {
    eventStreamControllers[playerId]?.close();
  }

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 0;

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.seekComplete),
    );
  }

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
  Future<void> setSourceBytes(String playerId, Uint8List bytes, {String? mimeType}) async {
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceUrl(String playerId, String url, {bool? isLocal, String? mimeType}) async {
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> stop(String playerId) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    eventStreamControllers.putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast());
    return eventStreamControllers[playerId]!.stream;
  }
}

class _FakeGlobalAudioplayersPlatform extends GlobalAudioplayersPlatformInterface {
  final StreamController<GlobalAudioEvent> _eventStreamController =
      StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => _eventStreamController.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioplayersPlatformInterface.instance = _FakeAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobalAudioplayersPlatform();
  });

  group('WallpaperService Tests', () {
    test('Singleton identity and pool size', () {
      final s1 = WallpaperService();
      final s2 = WallpaperService();
      expect(identical(s1, s2), isTrue);
      expect(WallpaperService.natureWallpapers.length, equals(30));
    });

    test('getDailyWallpaper returns valid URL based on day of year', () {
      final service = WallpaperService();

      // Day 1 (Jan 1) -> index 0
      final jan1 = DateTime(2026, 1, 1);
      final wp1 = service.getDailyWallpaper(jan1);
      expect(wp1, equals(WallpaperService.natureWallpapers[0]));

      // Day 30 (Jan 30) -> index 29
      final jan30 = DateTime(2026, 1, 30);
      final wp30 = service.getDailyWallpaper(jan30);
      expect(wp30, equals(WallpaperService.natureWallpapers[29]));

      // Day 31 (Jan 31) -> index 0 (cyclic)
      final jan31 = DateTime(2026, 1, 31);
      final wp31 = service.getDailyWallpaper(jan31);
      expect(wp31, equals(WallpaperService.natureWallpapers[0]));

      // Default (now)
      final current = service.getDailyWallpaper();
      expect(WallpaperService.natureWallpapers.contains(current), isTrue);
    });
  });

  group('GamificationService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GamificationService().resetForTesting();
    });

    test('Singleton identity and initial state', () async {
      final s1 = GamificationService();
      final s2 = GamificationService();
      expect(identical(s1, s2), isTrue);
      expect(s1.currentStreak, equals(0));
      expect(s1.totalXp, equals(0));
      expect(s1.hasReadToday, isFalse);
      expect(s1.weeklyActivity.length, equals(7));
      expect(s1.weeklyActivity.every((element) => element == false), isTrue);
    });

    test('recordReading first time today grants +10 XP and streak 1', () async {
      final service = GamificationService();
      await service.init();

      await service.recordReading(category: 'biblia');

      expect(service.totalXp, equals(10));
      expect(service.currentStreak, equals(1));
      expect(service.hasReadToday, isTrue);

      final todayWeekday = DateTime.now().weekday; // 1 (Mon) to 7 (Sun)
      expect(service.weeklyActivity[todayWeekday - 1], isTrue);
    });

    test('recordReading multiple times on same day maintains streak and XP', () async {
      final service = GamificationService();
      await service.init();

      await service.recordReading(category: 'biblia');
      expect(service.totalXp, equals(10));
      expect(service.currentStreak, equals(1));

      // Segunda leitura no mesmo dia
      await service.recordReading(category: 'escola_sabatina');
      expect(service.totalXp, equals(10));
      expect(service.currentStreak, equals(1));
      expect(service.hasReadToday, isTrue);
    });

    test('Streak progression: read yesterday increments streak', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final yesterdayStr =
          '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      // Simula leitura de ontem salva no SharedPreferences
      SharedPreferences.setMockInitialValues({
        'gamification_current_streak': 3,
        'gamification_total_xp': 30,
        'gamification_last_reading_date': yesterdayStr,
        'gamification_activity_dates': [yesterdayStr],
      });

      final service = GamificationService();
      await service.init();

      expect(service.currentStreak, equals(3));
      expect(service.hasReadToday, isFalse);

      // Leitura de hoje incrementa streak para 4 e XP para 40
      await service.recordReading(category: 'devocional');
      expect(service.currentStreak, equals(4));
      expect(service.totalXp, equals(40));
      expect(service.hasReadToday, isTrue);
    });

    test('Streak reset: last reading more than 1 day ago resets streak to 1', () async {
      final now = DateTime.now();
      final threeDaysAgo = DateTime(now.year, now.month, now.day - 3);
      final threeDaysAgoStr =
          '${threeDaysAgo.year.toString().padLeft(4, '0')}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'gamification_current_streak': 10,
        'gamification_total_xp': 100,
        'gamification_last_reading_date': threeDaysAgoStr,
        'gamification_activity_dates': [threeDaysAgoStr],
      });

      final service = GamificationService();
      await service.init();

      // Streak ativo expirou
      expect(service.currentStreak, equals(0));
      expect(service.hasReadToday, isFalse);

      // Nova leitura hoje reinicia streak em 1 e concede +10 XP
      await service.recordReading(category: 'biblia');
      expect(service.currentStreak, equals(1));
      expect(service.totalXp, equals(110));
      expect(service.hasReadToday, isTrue);
    });

    test('resetForTesting clears all values and SharedPreferences', () async {
      final service = GamificationService();
      await service.init();
      await service.recordReading(category: 'biblia');

      expect(service.totalXp, equals(10));
      await service.resetForTesting();

      expect(service.currentStreak, equals(0));
      expect(service.totalXp, equals(0));
      expect(service.hasReadToday, isFalse);
      expect(service.weeklyActivity.every((e) => e == false), isTrue);
    });
  });

  group('AudioService Tests', () {
    test('Singleton identity and default properties', () {
      final s1 = AudioService();
      final s2 = AudioService();
      expect(identical(s1, s2), isTrue);

      expect(s1.isPlaying, isFalse);
      expect(s1.isBuffering, isFalse);
      expect(s1.isInstrumental, isFalse);
      expect(s1.position, equals(Duration.zero));
      expect(s1.duration, equals(Duration.zero));
      expect(s1.volume, equals(1.0));
      expect(s1.currentHymnId, isNull);
    });

    test('getDefaultAudioUrl generates correct CDN links', () {
      final sungUrl = AudioService.getDefaultAudioUrl(1, isInstrumental: false);
      expect(sungUrl, contains('/cantado/hino_1.mp3'));

      final instUrl = AudioService.getDefaultAudioUrl(1, isInstrumental: true);
      expect(instUrl, contains('/instrumental/hino_1.mp3'));
    });

    test('setVolume updates volume and clamps correctly', () async {
      final service = AudioService();
      await service.setVolume(0.5);
      expect(service.volume, equals(0.5));

      await service.setVolume(1.5);
      expect(service.volume, equals(1.0));

      await service.setVolume(-0.2);
      expect(service.volume, equals(0.0));

      await service.setVolume(1.0);
    });

    test('toggleTrack alternates isInstrumental flag', () async {
      final service = AudioService();
      expect(service.isInstrumental, isFalse);

      await service.toggleTrack();
      expect(service.isInstrumental, isTrue);

      await service.toggleTrack();
      expect(service.isInstrumental, isFalse);
    });

    test('AudioService playback lifecycle (playHymn, pause, resume, seek, stop)', () async {
      final service = AudioService();
      await service.init();

      await service.playHymn(
        hymnId: 33,
        numero: '33',
        titulo: 'Castelo Forte',
        isInstrumental: false,
      );

      expect(service.currentHymnId, equals(33));
      expect(service.currentHymnNumber, equals('33'));
      expect(service.currentHymnTitle, equals('Castelo Forte'));
      expect(service.isPlaying, isTrue);
      expect(service.isBuffering, isFalse);

      await service.pause();
      expect(service.isPlaying, isFalse);

      await service.resume();
      expect(service.isPlaying, isTrue);

      await service.seek(const Duration(seconds: 45));
      expect(service.position, equals(const Duration(seconds: 45)));

      await service.stop();
      expect(service.isPlaying, isFalse);
      expect(service.position, equals(Duration.zero));
    });

    test('isHymnDownloaded and deleteDownloadedHymn for non-existing hymn', () async {
      final service = AudioService();
      expect(service.isHymnDownloaded(9999), isFalse);

      final deleted = await service.deleteDownloadedHymn(9999);
      expect(deleted, isFalse);
    });
  });
}
