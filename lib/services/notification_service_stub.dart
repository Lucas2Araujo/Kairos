import 'dart:async';

void schedulePlatformReminder(
  String id,
  String time,
  String title,
  String message,
  String route,
) {}

void cancelPlatformReminder(String id) {}

Future<bool> requestNotificationPermission() async => true;

Future<void> showInstantPlatformNotification(
  String id,
  String title,
  String message,
) async {}
