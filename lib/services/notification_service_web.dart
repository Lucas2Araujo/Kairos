import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('Notification')
extension type _JSNotification._(JSObject _) implements JSObject {
  external static String get permission;
  external static JSPromise<JSString> requestPermission();
  external factory _JSNotification(JSString title);
}

final Map<String, Timer> _activeWebTimers = {};

void schedulePlatformReminder(
  String id,
  String time,
  String title,
  String message,
  String route,
) {
  cancelPlatformReminder(id);

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

  _activeWebTimers[id] = Timer(initialDelay, () {
    _showWebNotification(title, message);
    _activeWebTimers[id] = Timer.periodic(const Duration(days: 1), (_) {
      _showWebNotification(title, message);
    });
  });
}

void cancelPlatformReminder(String id) {
  _activeWebTimers.remove(id)?.cancel();
}

Future<bool> requestNotificationPermission() async {
  try {
    final status = await _JSNotification.requestPermission().toDart;
    return status.toDart == 'granted';
  } catch (e) {
    debugPrint('[NotificationWeb] Erro ao solicitar permissão de notificação: $e');
    return false;
  }
}

void _showWebNotification(String title, String message) {
  try {
    if (_JSNotification.permission == 'granted') {
      _JSNotification(title.toJS);
    }
  } catch (e) {
    debugPrint('[NotificationWeb] Notificação: $title - $message ($e)');
  }
}
