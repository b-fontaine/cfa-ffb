import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  final base = RulesConfig();

  test('the defaults are those of the rules (ADR 0003)', () {
    expect(ClubSettings.defaults.passesRequired, 5);
    expect(ClubSettings.defaults.alertThreshold, 3);
    expect(ClubSettings.defaults.recallStaleSessions, 4);
    expect(ClubSettings.defaults.groupFailureSharePercent, 50);
    expect(ClubSettings.defaults.backupReminderDays, 30);
    expect(ClubSettings.defaults.applyTo(base), base);
  });

  test('applying keeps the parameters that are not adjustable', () {
    final custom = RulesConfig(trendWindow: 7, stagnationPasses: 9);

    final applied = ClubSettings.defaults
        .copyWith(passesRequired: 3)
        .applyTo(custom);

    expect(applied.passesRequired, 3);
    expect(applied.trendWindow, 7);
    expect(applied.stagnationPasses, 9);
    expect(applied.shapes, custom.shapes);
  });

  test('round-trips through the rules', () {
    const settings = ClubSettings(
      passesRequired: 3,
      alertThreshold: 4,
      recallStaleSessions: 6,
      groupFailureSharePercent: 30,
      backupReminderDays: 14,
    );

    expect(ClubSettings.fromRules(settings.applyTo(base)), settings);
  });

  group('bounds are those of RulesConfig, nothing more', () {
    ClubSettings with_({
      int? passes,
      int? alert,
      int? recall,
      int? share,
      int? days,
    }) => ClubSettings.defaults.copyWith(
      passesRequired: passes ?? 5,
      alertThreshold: alert ?? 3,
      recallStaleSessions: recall ?? 4,
      groupFailureSharePercent: share ?? 50,
      backupReminderDays: days ?? 30,
    );

    final accepted = <String, ClubSettings>{
      'passes 1': with_(passes: 1),
      'alert 1': with_(alert: 1),
      'alert equal to the persistent threshold': with_(alert: 5),
      'recall 1': with_(recall: 1),
      'share 1': with_(share: 1),
      'share 100': with_(share: 100),
      'delay 1': with_(days: 1),
      'delay 365': with_(days: 365),
    };
    for (final MapEntry(:key, :value) in accepted.entries) {
      test('accepts $key', () {
        expect(() => value.applyTo(base), returnsNormally);
      });
    }

    final refused = <String, ClubSettings>{
      'passes 0': with_(passes: 0),
      'alert 0': with_(alert: 0),
      'alert above the persistent threshold': with_(alert: 6),
      'recall 0': with_(recall: 0),
      'share 0': with_(share: 0),
      'share 101': with_(share: 101),
      'delay 0': with_(days: 0),
      'delay 366': with_(days: 366),
      'negative passes': with_(passes: -1),
    };
    for (final MapEntry(:key, :value) in refused.entries) {
      test('refuses $key', () {
        expect(
          () => value.applyTo(base),
          violation(InvariantCode.invalidRules),
        );
      });
    }
  });

  test('orDefaults keeps valid settings and replaces refused ones', () {
    final valid = ClubSettings.defaults.copyWith(passesRequired: 3);
    final refused = ClubSettings.defaults.copyWith(alertThreshold: 9);

    expect(valid.orDefaults(base), valid);
    expect(refused.orDefaults(base), ClubSettings.defaults);
  });
}
