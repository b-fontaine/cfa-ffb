import 'package:billard_cfa/entities/settings/data/in_memory_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/load_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/reset_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/save_settings.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/domain_world.dart';

void main() {
  late InMemorySettingsRepository repository;
  late RulesStore store;
  late LoadSettings load;
  late SaveSettings save;
  late ResetSettings reset;

  setUp(() {
    repository = InMemorySettingsRepository();
    store = RulesStore(RulesConfig());
    load = LoadSettings(repository, store);
    save = SaveSettings(repository, store);
    reset = ResetSettings(repository, store);
  });

  final custom = ClubSettings.defaults.copyWith(
    passesRequired: 3,
    backupReminderDays: 14,
  );

  test('loads the defaults when nothing is saved', () async {
    expect(ok(await load()), ClubSettings.defaults);
  });

  test('saving stores the settings and replaces the current rules', () async {
    final saved = ok(await save(custom));

    expect(saved, custom);
    expect(await repository.load(), custom);
    expect(ok(await load()), custom);
    expect(store.current.passesRequired, 3);
    expect(store.current.backupReminderDays, 14);
  });

  test('saving keeps the parameters that are not adjustable', () async {
    store.current = RulesConfig(trendWindow: 7);

    ok(await save(custom));

    expect(store.current.trendWindow, 7);
  });

  test('a refused configuration writes nothing and keeps the rules', () async {
    ok(await save(custom));

    final result = await save(custom.copyWith(alertThreshold: 6));

    expect(result, isA<Err<ClubSettings>>());
    expect(
      (result as Err<ClubSettings>).failure,
      isA<InvariantViolation>().having(
        (v) => v.code,
        'code',
        InvariantCode.invalidRules,
      ),
    );
    expect(await repository.load(), custom);
    expect(store.current.alertThreshold, 3);
    expect(store.current.passesRequired, 3);
  });

  test('a refused configuration on a new store writes nothing', () async {
    final result = await save(custom.copyWith(groupFailureSharePercent: 0));

    expect(result, isA<Err<ClubSettings>>());
    expect(await repository.load(), ClubSettings.defaults);
    expect(store.current, RulesConfig());
  });

  test('a stored value refused by the rules is read as the defaults', () async {
    await repository.save(custom.copyWith(alertThreshold: 99));

    expect(ok(await load()), ClubSettings.defaults);
  });

  test('reset forgets the settings and restores the default rules', () async {
    ok(await save(custom));

    final restored = ok(await reset());

    expect(restored, ClubSettings.defaults);
    expect(await repository.load(), ClubSettings.defaults);
    expect(store.current, RulesConfig());
  });
}
