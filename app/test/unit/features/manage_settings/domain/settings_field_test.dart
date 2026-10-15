import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/settings_field.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = RulesConfig();

  test('the screen bounds and steps are the documented ones', () {
    final actual = {
      for (final f in SettingsField.values) f: (f.min, f.max, f.step),
    };

    expect(actual, {
      SettingsField.passesRequired: (1, 10, 1),
      SettingsField.alertThreshold: (1, 5, 1),
      SettingsField.recallStaleSessions: (1, 12, 1),
      SettingsField.groupFailureSharePercent: (10, 100, 10),
      SettingsField.backupReminderDays: (7, 90, 5),
    });
  });

  for (final field in SettingsField.values) {
    group(field.name, () {
      test('both bounds are accepted by the rules', () {
        for (final value in [field.min, field.max]) {
          final settings = field.write(ClubSettings.defaults, value);
          expect(settings.applyTo(base), isA<RulesConfig>());
          expect(field.read(settings), value);
        }
      });

      test('the default value lies within the bounds', () {
        final value = field.read(ClubSettings.defaults);
        expect(value, inInclusiveRange(field.min, field.max));
      });

      test('both bounds are reachable from the default by steps', () {
        var value = field.read(ClubSettings.defaults);
        while (value < field.max) {
          value = (value + field.step).clamp(field.min, field.max);
        }
        expect(value, field.max);
        while (value > field.min) {
          value = (value - field.step).clamp(field.min, field.max);
        }
        expect(value, field.min);
      });
    });
  }
}
