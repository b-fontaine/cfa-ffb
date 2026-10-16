import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_consistency.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/json_reader.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';

/// Lit et valide le contenu d'une sauvegarde (section `data`).
///
/// Toute incohérence lève une `InvariantViolation` : `backupInvalid` (forme ou
/// valeur d'une entité), `backupInconsistent` (doublons, références
/// orphelines).
class BackupDecoder {
  const BackupDecoder();

  static const _read = JsonReader();

  /// [withSettings] : le format du fichier connaît la clé `settings` (format 2
  /// et suivants) ; dans un fichier du format 1 elle est refusée.
  ///
  /// [withAcknowledgements] : le format connaît la clé `alertAcknowledgements`
  /// (format 3 et suivants, ADR 0013) ; elle y est obligatoire, et refusée
  /// dans un fichier des formats 1 et 2 (la liste décodée est alors `null`).
  ///
  /// [withArchives] : le format connaît la clé `seasonArchives` (format 4,
  /// ADR 0019) ; elle y est obligatoire, et refusée dans un fichier des
  /// formats 1 à 3 (la liste décodée est alors vide).
  BackupSnapshot decode(
    Object? data, {
    bool withSettings = true,
    bool withAcknowledgements = true,
    bool withArchives = true,
  }) {
    try {
      final object = _read.object(data);
      if (!withSettings && object.containsKey('settings')) {
        throw const InvariantViolation(InvariantCode.backupInvalid);
      }
      if (!withAcknowledgements &&
          object.containsKey('alertAcknowledgements')) {
        throw const InvariantViolation(InvariantCode.backupInvalid);
      }
      if (!withArchives && object.containsKey('seasonArchives')) {
        throw const InvariantViolation(InvariantCode.backupInvalid);
      }
      final snapshot = _decodeData(
        object,
        withAcknowledgements: withAcknowledgements,
        withArchives: withArchives,
      );
      const BackupConsistency().check(snapshot);
      return snapshot;
    } on InvariantViolation catch (violation) {
      // Un invariant métier violé par une entité du fichier = fichier invalide.
      if (violation.code == InvariantCode.backupInconsistent) rethrow;
      throw const InvariantViolation(InvariantCode.backupInvalid);
    }
  }

  BackupSnapshot _decodeData(
    Map<String, Object?> data, {
    required bool withAcknowledgements,
    required bool withArchives,
  }) => BackupSnapshot(
    seasons: _read.objects(data['seasons']).map(_decodeSeason).toList(),
    students: _read.objects(data['students']).map(_decodeStudent).toList(),
    groups: _read.objects(data['groups']).map(_decodeGroup).toList(),
    sessionRecords: _read
        .objects(data['sessionRecords'])
        .map(_decodeSessionRecord)
        .toList(),
    attempts: _read.objects(data['attempts']).map(_decodeAttempt).toList(),
    assessments: _read
        .objects(data['assessments'])
        .map(_decodeAssessment)
        .toList(),
    plannedSessions: _read
        .objects(data['plannedSessions'])
        .map(_decodePlanned)
        .toList(),
    // Clé obligatoire : `list(null)` lève `backupInvalid`.
    blockAcquisitions: _read
        .objects(data['blockAcquisitions'])
        .map(_decodeAcquisition)
        .toList(),
    // Clé obligatoire du format 4 : `objects(null)` lève `backupInvalid`.
    seasonArchives: withArchives
        ? _read.objects(data['seasonArchives']).map(_decodeArchive).toList()
        : const [],
    settings: _decodeSettings(data['settings']),
    // Clé obligatoire du format 3 : `objects(null)` lève `backupInvalid`.
    alertAcknowledgements: withAcknowledgements
        ? _read
              .objects(data['alertAcknowledgements'])
              .map(_decodeAcknowledgement)
              .toList()
        : null,
  );

  /// Clé facultative ; si elle est présente, les cinq entiers sont exigés et
  /// la configuration doit être acceptée par `RulesConfig`.
  ClubSettings? _decodeSettings(Object? value) {
    if (value == null) return null;
    final json = _read.object(value);
    final settings = ClubSettings(
      passesRequired: _read.integer(json['passesRequired']),
      alertThreshold: _read.integer(json['alertThreshold']),
      recallStaleSessions: _read.integer(json['recallStaleSessions']),
      groupFailureSharePercent: _read.integer(json['groupFailureSharePercent']),
      backupReminderDays: _read.integer(json['backupReminderDays']),
    );
    // La configuration doit être acceptée par `RulesConfig` (sinon refus).
    return settings..applyTo(RulesConfig());
  }

  Season _decodeSeason(Map<String, Object?> json) => Season(
    id: SeasonId(_read.string(json['id'])),
    label: _read.string(json['label']),
    startDate: _read.dateTime(json['startDate']),
    endDate: _read.dateTime(json['endDate']),
    closedOn: json['closedOn'] == null ? null : _readDay(json['closedOn']),
  );

  /// Un jour entier : une date portant une heure est refusée.
  DateTime _readDay(Object? value) {
    final date = _read.dateTime(value);
    if (date != DateTime(date.year, date.month, date.day) &&
        date != DateTime.utc(date.year, date.month, date.day)) {
      throw const InvariantViolation(InvariantCode.backupInvalid);
    }
    return date;
  }

  SeasonArchive _decodeArchive(Map<String, Object?> json) => SeasonArchive(
    seasonId: SeasonId(_read.string(json['seasonId'])),
    audiences: [
      for (final a in _read.objects(json['audiences']))
        AudienceArchive(
          audience: _read.audience(a['audience']),
          sessionCount: _read.integer(a['sessionCount']),
          presenceCount: _read.integer(a['presenceCount']),
          possiblePresenceCount: _read.integer(a['possiblePresenceCount']),
          studentCount: _read.integer(a['studentCount']),
          attemptCount: _read.integer(a['attemptCount']),
        ),
    ],
    exercises: [
      for (final e in _read.objects(json['exercises']))
        ExerciseArchive(
          audience: _read.audience(e['audience']),
          exercise: ExerciseRef(
            blockId: _read.string(e['blockId']),
            number: _read.integer(e['exerciseNumber']),
          ),
          studentCount: _read.integer(e['studentCount']),
          attemptCount: _read.integer(e['attemptCount']),
          potted: _read.integer(e['potted']),
          total: _read.integer(e['total']),
        ),
    ],
  );

  Student _decodeStudent(Map<String, Object?> json) => Student(
    id: StudentId(_read.string(json['id'])),
    firstName: _read.string(json['firstName']),
    audienceHistory: [
      for (final change in _read.objects(json['audienceHistory']))
        AudienceChange(
          audience: _read.audience(change['audience']),
          effectiveFrom: _read.dateTime(change['effectiveFrom']),
        ),
    ],
  );

  Group _decodeGroup(Map<String, Object?> json) => Group(
    id: GroupId(_read.string(json['id'])),
    seasonId: SeasonId(_read.string(json['seasonId'])),
    name: _read.string(json['name']),
    audience: _read.audience(json['audience']),
    memberships: [
      for (final m in _read.objects(json['memberships']))
        Membership(
          studentId: StudentId(_read.string(m['studentId'])),
          from: _read.dateTime(m['from']),
          to: m['to'] == null ? null : _read.dateTime(m['to']),
        ),
    ],
  );

  SessionRecord _decodeSessionRecord(Map<String, Object?> json) =>
      SessionRecord(
        id: SessionId(_read.string(json['id'])),
        groupId: GroupId(_read.string(json['groupId'])),
        seasonId: SeasonId(_read.string(json['seasonId'])),
        date: _read.dateTime(json['date']),
        audience: _read.audience(json['audience']),
        present: {
          for (final id in _read.list(json['present']))
            StudentId(_read.string(id)),
        },
        mainBlockId: _read.optionalString(json['mainBlockId']),
        recallBlockId: _read.optionalString(json['recallBlockId']),
        sheetId: _read.optionalSheetId(json['sheetId']),
      );

  ExerciseAttempt _decodeAttempt(Map<String, Object?> json) => ExerciseAttempt(
    id: AttemptId(_read.string(json['id'])),
    studentId: StudentId(_read.string(json['studentId'])),
    sessionId: SessionId(_read.string(json['sessionId'])),
    exercise: ExerciseRef(
      blockId: _read.string(json['blockId']),
      number: _read.integer(json['exerciseNumber']),
    ),
    date: _read.dateTime(json['date']),
    passIndex: _read.integer(json['passIndex']),
    potted: _read.integer(json['potted']),
    total: _read.integer(json['total']),
  );

  MaturityAssessment _decodeAssessment(Map<String, Object?> json) =>
      MaturityAssessment(
        id: AssessmentId(_read.string(json['id'])),
        studentId: StudentId(_read.string(json['studentId'])),
        date: _read.dateTime(json['date']),
        concentration: _read.integer(json['concentration']),
        endurance: _read.integer(json['endurance']),
        frustration: _read.integer(json['frustration']),
        comment: _read.optionalString(json['comment']),
      );

  BlockAcquisition _decodeAcquisition(Map<String, Object?> json) =>
      BlockAcquisition(
        id: AcquisitionId(_read.string(json['id'])),
        studentId: StudentId(_read.string(json['studentId'])),
        blockId: _read.string(json['blockId']),
        date: _read.dateTime(json['date']),
        source:
            AcquisitionSource.values.asNameMap()[_read.string(
              json['source'],
            )] ??
            (throw const InvariantViolation(InvariantCode.backupInvalid)),
      );

  AlertAcknowledgement _decodeAcknowledgement(Map<String, Object?> json) =>
      AlertAcknowledgement(
        id: AcknowledgementId(_read.string(json['id'])),
        studentId: StudentId(_read.string(json['studentId'])),
        exercise: ExerciseRef(
          blockId: _read.string(json['blockId']),
          number: _read.integer(json['exerciseNumber']),
        ),
        lastAttemptId: AttemptId(_read.string(json['lastAttemptId'])),
        date: _read.dateTime(json['date']),
      );

  Session _decodePlanned(Map<String, Object?> json) => Session(
    id: _read.string(json['id']),
    title: _read.string(json['title']),
    date: _read.dateTime(json['date']),
    audience: _read.audience(json['audience']),
    groupId: switch (_read.optionalString(json['groupId'])) {
      null => null,
      final id => GroupId(id),
    },
    sheetId: _read.optionalSheetId(json['sheetId']),
  );
}
