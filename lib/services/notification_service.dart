import 'dart:async';
import 'package:flutter/foundation.dart';

import 'notification_service_stub.dart'
    if (dart.library.js_interop) 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_io.dart' as platform;

/// Serviço unificado de notificações locais offline para Web e Mobile/Desktop
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    notifyListeners();
  }

  /// Solicita permissão do sistema operacional / navegador
  Future<bool> requestPermission() async {
    return await platform.requestNotificationPermission();
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
    platform.cancelPlatformReminder(id);
  }

  /// Agenda o lembrete tradicional do Pôr do Sol de sexta-feira
  void scheduleFridaySunsetReminder({String time = '16:00'}) {
    scheduleDailyReminder(
      id: 'rem_sunset',
      time: time,
      title: 'Preparação para o Sábado',
      message: 'Vamos nos preparar para o sábado cantando hinos ao Senhor? O pôr do sol se aproxima!',
      route: '/hinario?filtro=sabado',
    );
  }
}

