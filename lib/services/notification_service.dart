import 'dart:async';
import 'package:flutter/foundation.dart';

import 'notification_service_stub.dart'
    if (dart.library.js_interop) 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_io.dart' as platform;
import 'solar_service.dart';
import 'theme_service.dart';

/// Serviço unificado de notificações locais offline para Web e Mobile/Desktop
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _scheduledSunsetTime;
  String? get scheduledSunsetTime => _scheduledSunsetTime;

  String? _scheduledSunsetCity;
  String? get scheduledSunsetCity => _scheduledSunsetCity;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    notifyListeners();
  }

  /// Solicita permissão do sistema operacional / navegador
  Future<bool> requestPermission() async {
    return await platform.requestNotificationPermission();
  }

  /// Dispara uma notificação local imediata (ex: Conquista ou Item de Avatar desbloqueado)
  Future<void> showInstantNotification({
    required String id,
    required String title,
    required String message,
  }) async {
    await platform.showInstantPlatformNotification(id, title, message);
  }

  /// Agenda um lembrete diário local
  void scheduleDailyReminder({
    required String id,
    required String time, // "07:00"
    required String title,
    required String message,
    required String route,
  }) {
    platform.schedulePlatformReminder(id, time, title, message, route);
  }

  /// Cancela um lembrete agendado
  void cancelReminder(String id) {
    if (id == 'rem_sunset') {
      _scheduledSunsetTime = null;
      _scheduledSunsetCity = null;
      notifyListeners();
    }
    platform.cancelPlatformReminder(id);
  }

  /// Agenda a notificação de "Feliz Sábado!" para o pôr do sol da sexta-feira
  void scheduleFridaySunsetReminder({
    String time = '18:00',
    String? cityName,
  }) {
    final locationLabel =
        (cityName != null && cityName.trim().isNotEmpty) ? ' em $cityName' : '';
    _scheduledSunsetTime = time;
    _scheduledSunsetCity = cityName;
    platform.schedulePlatformReminder(
      'rem_sunset',
      time,
      'Feliz Sábado!',
      'O sol se pôs$locationLabel ($time). Desejamos a você e sua família um Feliz Sábado na presença de Deus!',
      '/pordosol',
      weekday: DateTime.friday,
    );
    notifyListeners();
  }

  /// Calcula o horário exato do pôr do sol da sexta-feira para a cidade salva
  /// (ou informada) e agenda a notificação de Feliz Sábado.
  Future<DateTime> scheduleFridaySunsetReminderForCity({
    SolarCity? city,
    DateTime? referenceDate,
  }) async {
    final resolvedCity = city ?? await SolarService.getSavedCity();
    final sunset = SolarService.getFridaySunset(
      referenceDate: referenceDate,
      city: resolvedCity,
    );
    final timeStr = SolarService.formatTime(sunset);
    scheduleFridaySunsetReminder(
      time: timeStr,
      cityName: resolvedCity.displayName,
    );
    return sunset;
  }

  /// Sincroniza o lembrete de pôr do sol com a preferência atual do usuário.
  Future<void> syncSunsetReminder() async {
    if (ThemeService().sunsetReminderEnabled) {
      await scheduleFridaySunsetReminderForCity();
    } else {
      cancelReminder('rem_sunset');
    }
  }
}
