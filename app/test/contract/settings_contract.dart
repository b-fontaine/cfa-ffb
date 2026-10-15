import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Suite unique du port [SettingsRepository], exécutée contre chaque
/// implémentation. Le port ne valide rien : les bornes sont celles de
/// `RulesConfig` (testées avec `ClubSettings`).
void settingsContract(
  String label,
  Future<({SettingsRepository repository, Future<void> Function() close})>
  Function()
  open,
) {
  group('$label : contrat des réglages', () {
    late SettingsRepository repository;
    late Future<void> Function() close;

    setUp(() async {
      final opened = await open();
      repository = opened.repository;
      close = opened.close;
    });
    tearDown(() => close());

    test('loads the defaults on a new store', () async {
      expect(await repository.load(), ClubSettings.defaults);
    });

    test('reads back what was saved', () async {
      const saved = ClubSettings(
        passesRequired: 3,
        alertThreshold: 4,
        recallStaleSessions: 6,
        groupFailureSharePercent: 30,
        backupReminderDays: 14,
      );

      await repository.save(saved);

      expect(await repository.load(), saved);
    });

    test('replaces the previous settings', () async {
      await repository.save(ClubSettings.defaults.copyWith(passesRequired: 3));
      await repository.save(ClubSettings.defaults.copyWith(passesRequired: 7));

      expect((await repository.load()).passesRequired, 7);
    });

    test('reset brings the defaults back', () async {
      await repository.save(
        ClubSettings.defaults.copyWith(backupReminderDays: 7),
      );

      await repository.reset();

      expect(await repository.load(), ClubSettings.defaults);
    });

    test('reset on a new store is harmless', () async {
      await repository.reset();

      expect(await repository.load(), ClubSettings.defaults);
    });
  });
}
