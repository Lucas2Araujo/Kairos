import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kairos_web/services/notification_service.dart';
import 'package:kairos_web/services/solar_service.dart';
import 'package:kairos_web/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sunset Feliz Sábado Notification Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      NotificationService().cancelReminder('rem_sunset');
    });

    test('SolarService persists chosen city and calculates Friday sunset time', () async {
      final manaus = SolarService.predefinedCities.firstWhere(
        (c) => c.name == 'Manaus',
      );
      await SolarService.saveCity(manaus);

      final loaded = await SolarService.getSavedCity();
      expect(loaded.name, 'Manaus');
      expect(loaded.state, 'AM');

      final refDate = DateTime(2026, 5, 13, 10, 0); // Wednesday
      final fridaySunset = SolarService.getFridaySunset(
        referenceDate: refDate,
        city: loaded,
      );
      expect(fridaySunset.weekday, DateTime.friday);
      expect(fridaySunset.hour, inInclusiveRange(17, 19));
    });

    test('NotificationService schedules Feliz Sábado using saved city sunset', () async {
      final recife = SolarService.predefinedCities.firstWhere(
        (c) => c.name == 'Recife',
      );
      await SolarService.saveCity(recife);

      final refDate = DateTime(2026, 5, 15, 9, 0); // Friday morning
      final sunset = await NotificationService()
          .scheduleFridaySunsetReminderForCity(referenceDate: refDate);
      final expectedTime = SolarService.formatTime(sunset);

      expect(NotificationService().scheduledSunsetTime, expectedTime);
      expect(NotificationService().scheduledSunsetCity, recife.displayName);
    });

    test('syncSunsetReminder schedules when enabled and cancels when disabled', () async {
      final themeService = ThemeService();
      await themeService.init();

      await themeService.setSunsetReminderEnabled(true);
      await NotificationService().syncSunsetReminder();
      expect(NotificationService().scheduledSunsetTime, isNotNull);
      expect(NotificationService().scheduledSunsetCity, isNotNull);

      await themeService.setSunsetReminderEnabled(false);
      await NotificationService().syncSunsetReminder();
      expect(NotificationService().scheduledSunsetTime, isNull);
      expect(NotificationService().scheduledSunsetCity, isNull);
    });
  });
}
