import 'dart:async';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/avatar_config.dart';
import 'package:kairos_web/services/audio_service.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/spiritual_focus_tracker.dart';
import 'package:kairos_web/views/home/widgets/kairos_lamp_mascot.dart';
import 'package:kairos_web/views/profile/avatar_builder_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGlobalAudioplayersPlatform extends GlobalAudioplayersPlatformInterface {
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
  Future<void> setSourceUrl(String playerId, String url, {bool? isLocal, String? mimeType}) async {}

  @override
  Future<void> setSourceBytes(String playerId, dynamic bytes, {String? mimeType}) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return eventStreamControllers
        .putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast())
        .stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioplayersPlatformInterface.instance = _FakeAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobalAudioplayersPlatform();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final g = GamificationService();
    await g.resetForTesting();
  });

  group('Gamification 2.0 (Lamparina, Missões e Anti-AFK)', () {
    test('Configuração de Meta Diária de Tempo com Deus', () async {
      final g = GamificationService();
      expect(g.dailyGoalMinutes, 15); // default
      expect(g.isDailyGoalReached, isFalse);

      await g.setDailyGoalMinutes(10);
      expect(g.dailyGoalMinutes, 10);

      // Adiciona 9 minutos e 59 segundos
      await g.addFocusTime(seconds: 599);
      expect(g.todayFocusMinutes, 9);
      expect(g.isDailyGoalReached, isFalse);
      expect(g.mission1TimeWithGod, isFalse);

      // Completa 10 minutos
      await g.addFocusTime(seconds: 1);
      expect(g.todayFocusMinutes, 10);
      expect(g.isDailyGoalReached, isTrue);
      expect(g.mission1TimeWithGod, isTrue);
    });

    test('Regras da Ofensiva: Meia Ofensiva (1-2 missões) vs Chama Completa (>=3 c/ Quiz)', () async {
      final g = GamificationService();

      expect(g.completedMissionsCount, 0);
      expect(g.isHalfStreakActive, isFalse);
      expect(g.isFullFlameActive, isFalse);

      // Missão 2: Palavra Viva
      await g.recordBibleChapterRead();
      expect(g.mission2LivingWord, isTrue);
      expect(g.completedMissionsCount, 1);
      expect(g.isHalfStreakActive, isTrue);
      expect(g.isFullFlameActive, isFalse);
      expect(g.streakFlameType, FlameType.halfFlame);
      expect(g.azeiteMultiplier, 1.0);

      // Missão 3: Pão Diário
      await g.recordDevotionalRead();
      expect(g.mission3DailyBread, isTrue);
      expect(g.completedMissionsCount, 2);
      expect(g.isHalfStreakActive, isTrue);
      expect(g.isFullFlameActive, isFalse);

      // Missão 1: Meta de tempo (3 missões, mas SEM o Quiz!)
      await g.addFocusTime(seconds: 15 * 60);
      expect(g.mission1TimeWithGod, isTrue);
      expect(g.completedMissionsCount, 3);
      // Sem quiz ainda é Meia Ofensiva (regra explícita da spec: Quiz é OBRIGATÓRIO para Chama Completa)
      expect(g.isHalfStreakActive, isTrue);
      expect(g.isFullFlameActive, isFalse);

      // Missão 4: Conclui Quiz da Lição
      await g.recordLessonQuizCompleted();
      expect(g.mission4LessonQuiz, isTrue);
      expect(g.completedMissionsCount, 4);
      expect(g.isFullFlameActive, isTrue);
      expect(g.streakFlameType, FlameType.fullFlame);
      expect(g.azeiteMultiplier, 1.5);
    });

    test('Mascote Lamparina Reativo: Estados matutino, vespertino e chamas', () async {
      final g = GamificationService();

      // Sem atividade pela manhã
      final morningState = g.evaluateMascotState(currentHour: 8);
      expect(morningState, LampMascotState.morningIdle);

      // Sem atividade à noite
      final nightState = g.evaluateMascotState(currentHour: 20);
      expect(nightState, LampMascotState.eveningSleepy);

      // Com 1 missão concluída
      await g.recordBibleChapterRead();
      final halfState = g.evaluateMascotState(currentHour: 20);
      expect(halfState, LampMascotState.halfFlame);

      // Com Chama Completa
      await g.recordDevotionalRead();
      await g.recordLessonQuizCompleted();
      final fullState = g.evaluateMascotState(currentHour: 20);
      expect(fullState, LampMascotState.fullFlame);
    });

    test('Anti-AFK Tracker pausa contagem após 120s sem interação', () {
      final g = GamificationService();
      final tracker = SpiritualFocusTrackerState();

      tracker.initForTesting(gamificationService: g, audioService: AudioService());

      // 60s com interação: acumula foco
      tracker.setInactivityForTesting(0);
      for (int i = 0; i < 60; i++) {
        tracker.tickForTesting();
      }
      expect(g.todayFocusSeconds, 60);

      // Ultrapassa 120s de inatividade (ex: 121s)
      tracker.setInactivityForTesting(121);
      // Mais 30 ticks sem interação e sem áudio: NÃO devem pontuar
      for (int i = 0; i < 30; i++) {
        tracker.tickForTesting();
      }
      expect(g.todayFocusSeconds, 60); // Permanece 60!

      // Se o usuário tocar na tela (inactivity reseta para 0)
      tracker.setInactivityForTesting(0);
      tracker.tickForTesting();
      expect(g.todayFocusSeconds, 61);
    });

    test('Anti-AFK Tracker NÃO pausa se AudioService estiver tocando', () {
      final g = GamificationService();
      final tracker = SpiritualFocusTrackerState();
      final audio = AudioService();
      audio.setPlayingForTesting(true);

      tracker.initForTesting(gamificationService: g, audioService: audio);

      // Inatividade de 200 segundos, mas com áudio tocando
      tracker.setInactivityForTesting(200);
      for (int i = 0; i < 15; i++) {
        tracker.tickForTesting();
      }
      // Deve continuar acumulando tempo
      expect(g.todayFocusSeconds, 15);

      audio.setPlayingForTesting(false);
    });
  });

  group('Avatar Kairós Modular', () {
    test('Serialização e Desserialização do AvatarConfig', () {
      const original = AvatarConfig(
        skinToneIndex: 2,
        hairStyleIndex: 3,
        hairColorIndex: 4,
        expressionIndex: 1,
        glassesIndex: 2,
        accessoryIndex: 3,
        backgroundColorIndex: 4,
      );

      final json = original.toJson();
      final recovered = AvatarConfig.fromJson(json);

      expect(recovered.skinToneIndex, 2);
      expect(recovered.hairStyleIndex, 3);
      expect(recovered.hairColorIndex, 4);
      expect(recovered.expressionIndex, 1);
      expect(recovered.glassesIndex, 2);
      expect(recovered.accessoryIndex, 3);
      expect(recovered.backgroundColorIndex, 4);
    });

    testWidgets('Renderiza AvatarCustomWidget e KairosLampMascotWidget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AvatarCustomWidget(
                  config: AvatarConfig(),
                  size: 64,
                ),
                KairosLampMascotWidget(
                  state: LampMascotState.fullFlame,
                  oilFill: 0.8,
                  size: 50,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AvatarCustomWidget), findsOneWidget);
      expect(find.byType(KairosLampMascotWidget), findsOneWidget);
    });
  });
}
