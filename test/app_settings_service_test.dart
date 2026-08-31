import 'package:bookmark_app/services/app_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsService', () {
    const service = AppSettingsService();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to system theme', () async {
      expect(await service.loadThemeMode(), ThemeMode.system);
    });

    test('persists selected theme mode', () async {
      await service.saveThemeMode(ThemeMode.dark);
      expect(await service.loadThemeMode(), ThemeMode.dark);

      await service.saveThemeMode(ThemeMode.light);
      expect(await service.loadThemeMode(), ThemeMode.light);
    });
  });
}
