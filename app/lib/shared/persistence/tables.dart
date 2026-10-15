import 'package:billard_cfa/shared/persistence/iso_date_time_converter.dart';
import 'package:drift/drift.dart';

/// Colonnes communes aux agrégats (ADR 0001) : identifiant UUID texte, ordre
/// d'insertion stable, horodatages et suppression logique, prévus dès la
/// version 1 pour une synchronisation ultérieure (last-write-wins par
/// `updatedAt`).
mixin AuditColumns on Table {
  /// Ordre d'insertion ; ne change jamais lorsqu'une ligne est remplacée.
  IntColumn get seq => integer().autoIncrement()();

  TextColumn get id => text().unique()();

  TextColumn get createdAt => text().map(const IsoDateTimeConverter())();

  TextColumn get updatedAt => text().map(const IsoDateTimeConverter())();

  /// Non nul : ligne supprimée logiquement (jamais effacée physiquement).
  TextColumn get deletedAt =>
      text().map(const IsoDateTimeConverter()).nullable()();
}

/// Données minimales (mineurs) : prénom et public uniquement `[U]`.
@DataClassName('StudentRow')
class Students extends Table with AuditColumns {
  TextColumn get firstName => text()();
}

/// Historique du public d'un élève (jamais réécrit, seulement prolongé).
@DataClassName('AudienceChangeRow')
class StudentAudienceChanges extends Table {
  TextColumn get studentId => text().references(Students, #id)();

  IntColumn get position => integer()();

  TextColumn get audience => text()();

  TextColumn get effectiveFrom => text().map(const IsoDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {studentId, position};
}

@DataClassName('SeasonRow')
class Seasons extends Table with AuditColumns {
  TextColumn get label => text()();

  TextColumn get startDate => text().map(const IsoDateTimeConverter())();

  TextColumn get endDate => text().map(const IsoDateTimeConverter())();
}

@DataClassName('GroupRow')
class Groups extends Table with AuditColumns {
  TextColumn get seasonId => text()();

  TextColumn get name => text()();

  TextColumn get audience => text()();
}

/// Appartenance d'élèves à un groupe (période ouverte si `toDate` est nul).
@DataClassName('MembershipRow')
class GroupMemberships extends Table {
  TextColumn get groupId => text().references(Groups, #id)();

  IntColumn get position => integer()();

  TextColumn get studentId => text()();

  TextColumn get fromDate => text().map(const IsoDateTimeConverter())();

  TextColumn get toDate =>
      text().map(const IsoDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {groupId, position};
}

@DataClassName('SessionRecordRow')
class SessionRecords extends Table with AuditColumns {
  TextColumn get groupId => text()();

  TextColumn get seasonId => text()();

  TextColumn get date => text().map(const IsoDateTimeConverter())();

  TextColumn get audience => text()();

  TextColumn get mainBlockId => text().nullable()();

  TextColumn get recallBlockId => text().nullable()();

  /// Séance du catalogue notée (ajoutée au schéma version 4, ADR 0007). Les
  /// séances du catalogue sont des assets : pas de clé étrangère ; nul =
  /// séance ouverte sans séance du catalogue.
  TextColumn get sheetId => text().nullable()();
}

@DataClassName('PresenceRow')
class SessionPresences extends Table {
  TextColumn get sessionId => text().references(SessionRecords, #id)();

  TextColumn get studentId => text()();

  @override
  Set<Column<Object>> get primaryKey => {sessionId, studentId};
}

@DataClassName('AttemptRow')
@TableIndex(name: 'attempts_by_student', columns: {#studentId})
@TableIndex(name: 'attempts_by_session', columns: {#sessionId})
class Attempts extends Table with AuditColumns {
  TextColumn get studentId => text()();

  TextColumn get sessionId => text()();

  TextColumn get blockId => text()();

  IntColumn get exerciseNumber => integer()();

  TextColumn get date => text().map(const IsoDateTimeConverter())();

  IntColumn get passIndex => integer()();

  IntColumn get potted => integer()();

  IntColumn get total => integer()();
}

@DataClassName('AssessmentRow')
@TableIndex(name: 'assessments_by_student', columns: {#studentId})
class Assessments extends Table with AuditColumns {
  TextColumn get studentId => text()();

  TextColumn get date => text().map(const IsoDateTimeConverter())();

  IntColumn get concentration => integer()();

  IntColumn get endurance => integer()();

  IntColumn get frustration => integer()();

  /// Remarque libre (ajoutée au schéma version 2).
  TextColumn get comment => text().nullable()();
}

@DataClassName('PlannedSessionRow')
class PlannedSessions extends Table with AuditColumns {
  TextColumn get title => text()();

  /// Jour de la séance (schéma version 4, ADR 0007 ; la table est recréée et
  /// les lignes antérieures prennent leur date de création).
  TextColumn get date => text().map(const IsoDateTimeConverter())();

  TextColumn get audience => text()();

  /// Groupe qui suivra la séance (version 4, nullable). Pas de clé étrangère :
  /// les groupes sont supprimés logiquement et l'affichage traite un groupe
  /// disparu sans échouer.
  TextColumn get groupId => text().nullable()();

  /// Séance du catalogue suivie (ajoutée au schéma version 3). Les séances du
  /// catalogue sont des assets : pas de clé étrangère ; nul = séance libre.
  TextColumn get sheetId => text().nullable()();
}

/// Blocs déclarés acquis au positionnement (schéma version 5, ADR 0008).
/// Pas de clé étrangère : suppression logique, blocs issus d'un asset.
@DataClassName('BlockAcquisitionRow')
@TableIndex(name: 'acquisitions_by_student', columns: {#studentId})
class BlockAcquisitions extends Table with AuditColumns {
  TextColumn get studentId => text()();

  TextColumn get blockId => text()();

  /// Jour du positionnement (normalisé).
  TextColumn get date => text().map(const IsoDateTimeConverter())();

  /// Nom de `AcquisitionSource`.
  TextColumn get source => text()();
}

/// Sauvegardes enregistrées sur l'appareil (rappel de sauvegarde) : une ligne
/// par export, la plus récente fait foi. Donnée locale, hors fichier de
/// sauvegarde.
@DataClassName('BackupExportRow')
class BackupExports extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get exportedAt => text().map(const IsoDateTimeConverter())();

  /// Passages du club au moment de l'export.
  IntColumn get attemptCount => integer()();
}
