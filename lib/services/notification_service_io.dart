import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/database/database_manager.dart';

final Map<String, Timer> _activeTimers = {};

void schedulePlatformReminder(
  String id,
  String time,
  String title,
  String message,
  String route,
) {
  cancelPlatformReminder(id);

  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return;
  }

  // Calcula delay até o próximo horário (HH:mm)
  final parts = time.split(':');
  if (parts.length != 2) return;
  final targetHour = int.tryParse(parts[0]) ?? 7;
  final targetMinute = int.tryParse(parts[1]) ?? 0;

  final now = DateTime.now();
  var scheduled = DateTime(now.year, now.month, now.day, targetHour, targetMinute);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }

  final initialDelay = scheduled.difference(now);

  _activeTimers[id] = Timer(initialDelay, () {
    _triggerReminder(id, title, message, route);
    // Reagenda para o dia seguinte (periódico de 24 horas)
    _activeTimers[id] = Timer.periodic(const Duration(days: 1), (_) {
      _triggerReminder(id, title, message, route);
    });
  });

  // Persiste no SQLite hinario.db de forma assíncrona
  _persistReminderInDb(id, time, title, message, route);
}

void cancelPlatformReminder(String id) {
  _activeTimers.remove(id)?.cancel();
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return;
  }
  _removeReminderFromDb(id);
}

Future<bool> requestNotificationPermission() async {
  return true;
}

void _triggerReminder(String id, String title, String message, String route) {
  debugPrint('[NotificationIO] Lembrete disparado ($id): $title - $message');
}

Future<void> _persistReminderInDb(
  String id,
  String time,
  String title,
  String message,
  String route,
) async {
  try {
    final db = await DatabaseManager().getDatabase('hinario.db');
    db.execute('''
      INSERT INTO notification_reminders (id, reminder_type, enabled, time, days_of_week_json, title, message, route)
      VALUES (?, ?, 1, ?, '[0,1,2,3,4,5,6]', ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        time = excluded.time,
        enabled = 1,
        title = excluded.title,
        message = excluded.message,
        route = excluded.route;
    ''', [id, id, time, title, message, route]);
  } catch (e) {
    debugPrint('[NotificationIO] Erro ao persistir lembrete no DB: $e');
  }
}

Future<void> _removeReminderFromDb(String id) async {
  try {
    final db = await DatabaseManager().getDatabase('hinario.db');
    db.execute('DELETE FROM notification_reminders WHERE id = ?;', [id]);
  } catch (e) {
    debugPrint('[NotificationIO] Erro ao remover lembrete do DB: $e');
  }
}
