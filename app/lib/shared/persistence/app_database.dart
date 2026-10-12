import 'package:billard_cfa/shared/persistence/app_database.steps.dart';
import 'package:billard_cfa/shared/persistence/iso_date_time_converter.dart';
import 'package:billard_cfa/shared/persistence/tables.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Base SQLite locale (drift) : source de vérité des données du club.
///
/// Le constructeur prend un [QueryExecutor] : `NativeDatabase.memory()` en
/// test, fichier natif ou wasm via `openAppDatabase` en production.
@DriftDatabase(
  tables: [
    Students,
    StudentAudienceChanges,
    Seasons,
    Groups,
    GroupMemberships,
    SessionRecords,
    SessionPresences,
    Attempts,
    Assessments,
    PlannedSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Version du schéma SQL. Elle est indépendante de la version du format de
  /// sauvegarde JSON (`BackupCodec.currentVersion`).
  static const currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    // Une base écrite par une version plus récente est refusée ; les
    // migrations s'enchaînent (stepByStep, après `dart run drift_dev
    // make-migrations`), chacune avec son test dans
    // test/unit/shared/persistence/migration_test.dart.
    onUpgrade: (migrator, from, to) async {
      if (from > to) throw DowngradeNotSupported(from: from, to: to);
      await stepByStep(
        // Version 2 : remarque libre sur le bilan de maturité.
        from1To2: (m, schema) async {
          await m.addColumn(schema.assessments, schema.assessments.comment);
        },
      )(migrator, from, to);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// La base a été écrite par une version plus récente de l'application : on
/// refuse de l'ouvrir plutôt que de risquer d'altérer des données.
class DowngradeNotSupported implements Exception {
  const DowngradeNotSupported({required this.from, required this.to});

  final int from;
  final int to;

  @override
  String toString() =>
      'DowngradeNotSupported(base en version $from, application en $to)';
}
