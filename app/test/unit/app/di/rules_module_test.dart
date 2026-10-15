import 'dart:io';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/di/rules_module.dart';
import 'package:billard_cfa/entities/settings/data/in_memory_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/reset_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/save_settings.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show Environment;

class _Module extends RulesModule;

void main() {
  group('the rules store', () {
    test('starts from the defaults on a new installation', () async {
      final store = await _Module().rulesStore(InMemorySettingsRepository());

      expect(store.current, RulesConfig());
    });

    test('starts from the stored settings', () async {
      final repository = InMemorySettingsRepository();
      await repository.save(
        ClubSettings.defaults.copyWith(
          passesRequired: 2,
          backupReminderDays: 9,
        ),
      );

      final store = await _Module().rulesStore(repository);

      expect(store.current.passesRequired, 2);
      expect(store.current.backupReminderDays, 9);
    });

    test('starts from the defaults when the stored value is refused', () async {
      final repository = InMemorySettingsRepository();
      await repository.save(ClubSettings.defaults.copyWith(alertThreshold: 99));

      final store = await _Module().rulesStore(repository);

      expect(store.current, RulesConfig());
    });

    test('the rules factory reads the current value of the store', () {
      final store = RulesStore(RulesConfig());
      final module = _Module();

      final before = module.rulesConfig(store);
      store.current = RulesConfig(passesRequired: 2);
      final after = module.rulesConfig(store);

      expect(before.passesRequired, 5);
      expect(after.passesRequired, 2);
    });
  });

  group('the graph', () {
    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      await getIt.reset();
    });
    tearDown(getIt.reset);

    test('resolves the current rules after a setting is saved', () async {
      await configureDependencies(environment: Environment.test);
      expect(getIt<RulesConfig>().passesRequired, 5);

      await getIt<SaveSettings>()(
        ClubSettings.defaults.copyWith(passesRequired: 3),
      );

      expect(getIt<RulesConfig>().passesRequired, 3);

      await getIt<ResetSettings>()();

      expect(getIt<RulesConfig>().passesRequired, 5);
    });

    test('the settings survive a restart of the production graph', () async {
      final directory = await Directory.systemTemp.createTemp('billard_cfa_s');
      addTearDown(() => directory.delete(recursive: true));
      Future<void> start() => configureDependencies(
        settings: DatabaseSettings(
          native: DriftNativeOptions(
            databaseDirectory: () async => directory,
            tempDirectoryPath: () async => directory.path,
          ),
        ),
      );

      await start();
      await getIt<SaveSettings>()(
        ClubSettings.defaults.copyWith(
          passesRequired: 3,
          backupReminderDays: 14,
        ),
      );
      await getIt.reset();
      await start();

      expect(getIt<RulesConfig>().passesRequired, 3);
      expect(getIt<RulesConfig>().backupReminderDays, 14);
    });
  });

  test('no singleton of the generated graph reaches RulesConfig', () {
    // Une instance de `RulesConfig` conservée par un singleton, directement ou
    // à travers ses dépendances, ignorerait un changement de réglage
    // (ADR 0012) : on suit les dépendances du graphe généré à toute profondeur.
    final config = File('lib/app/di/injection.config.dart').readAsStringSync();
    final head = RegExp(r'^(\w+)(?:Async)?<(?:_i\d+\.)?(\w+)>');
    final dependency = RegExp(r'gh<(?:_i\d+\.)?(\w+)>\(');
    final deps = <String, Set<String>>{};
    final singletons = <String>{};
    for (final chunk in config.split(RegExp(r'\n    gh\.')).skip(1)) {
      final m = head.firstMatch(chunk);
      if (m == null) continue;
      final type = m.group(2)!;
      deps[type] = {for (final g in dependency.allMatches(chunk)) g.group(1)!};
      if (m.group(1)!.toLowerCase().contains('singleton')) singletons.add(type);
    }
    expect(deps, isNotEmpty, reason: 'the graph could not be parsed');

    bool reaches(String type, Set<String> seen) {
      if (type == 'RulesConfig') return true;
      if (!seen.add(type)) return false;
      return (deps[type] ?? const <String>{}).any((d) => reaches(d, seen));
    }

    final offenders = [
      for (final s in singletons)
        if (reaches(s, {})) s,
    ];

    expect(offenders, isEmpty, reason: offenders.join(', '));
  });
}
