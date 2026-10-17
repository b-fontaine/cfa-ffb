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
    BlockAcquisitions,
    AlertAcknowledgements,
    BackupExports,
    AppSettings,
    SeasonArchiveAudiences,
    SeasonArchiveExercises,
    RunProgressEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Version du schéma SQL. Elle est indépendante de la version du format de
  /// sauvegarde JSON (`BackupCodec.currentVersion`).
  static const currentSchemaVersion = 11;

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
        // Version 3 : séance du catalogue liée à une séance planifiée.
        from2To3: (m, schema) async {
          await m.addColumn(
            schema.plannedSessions,
            schema.plannedSessions.sheetId,
          );
        },
        // Version 4 (ADR 0007) : date obligatoire et groupe facultatif sur la
        // séance planifiée (table recréée ; les lignes existantes prennent
        // leur date de création), séance du catalogue notée par une saisie.
        from3To4: (m, schema) async {
          await m.alterTable(
            TableMigration(
              schema.plannedSessions,
              newColumns: [
                schema.plannedSessions.date,
                schema.plannedSessions.groupId,
              ],
              columnTransformer: {
                schema.plannedSessions.date: schema.plannedSessions.createdAt,
              },
            ),
          );
          await m.addColumn(
            schema.sessionRecords,
            schema.sessionRecords.sheetId,
          );
        },
        // Version 5 (ADR 0008) : blocs acquis au positionnement.
        from4To5: (m, schema) async {
          await m.createTable(schema.blockAcquisitions);
          await m.createIndex(schema.acquisitionsByStudent);
        },
        // Version 6 : mémoire de la dernière sauvegarde (rappel U6).
        from5To6: (m, schema) async {
          await m.createTable(schema.backupExports);
        },
        // Version 7 (ADR 0012) : réglages du club (une ligne).
        from6To7: (m, schema) async {
          await m.createTable(schema.appSettings);
        },
        // Version 8 (ADR 0013) : acquittements d'alertes (« Vu »).
        from7To8: (m, schema) async {
          await m.createTable(schema.alertAcknowledgements);
          await m.createIndex(schema.acknowledgementsByStudent);
        },
        // Version 9 (ADR 0019) : clôture de saison et archive agrégée non
        // nominative. Migration additive : aucune donnée n'est transformée.
        from8To9: (m, schema) async {
          await m.addColumn(schema.seasons, schema.seasons.closedOn);
          await m.createTable(schema.seasonArchiveAudiences);
          await m.createTable(schema.seasonArchiveExercises);
        },
        // Version 10 (ADR 0020) : séances guidées en cours. Migration
        // additive : une table vide et ses index, aucune donnée transformée.
        from9To10: (m, schema) async {
          await m.createTable(schema.runProgressEntries);
          await m.createIndex(schema.runProgressByGroup);
          await m.createIndex(schema.runProgressByRecord);
        },
        // Version 11 (ADR 0023) : étiquettes de la note de jeu, sur la saisie
        // et sur la séance guidée en cours. Migration additive : une colonne
        // de texte par table, `'[]'` pour les lignes existantes.
        from10To11: (m, schema) async {
          await m.addColumn(
            schema.sessionRecords,
            schema.sessionRecords.tagsJson,
          );
          await m.addColumn(
            schema.runProgressEntries,
            schema.runProgressEntries.tagsJson,
          );
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
