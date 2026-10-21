import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:injectable/injectable.dart';

/// Lit toutes les données d'un stock (club ou base locale) dans une
/// [BackupSnapshot] : l'unique endroit où l'on liste ce que contient une
/// sauvegarde (un export du club et un export de la base locale, FB7c, ne
/// peuvent pas diverger). Lecture seule.
class BackupSnapshotReader {
  BackupSnapshotReader(
    this._seasons,
    this._seasonArchives,
    this._students,
    this._groups,
    this._sessionRecords,
    this._attempts,
    this._acquisitions,
    this._acknowledgements,
    this._assessments,
    this._plannedSessions,
  );

  final SeasonRepository _seasons;
  final SeasonArchiveRepository _seasonArchives;
  final StudentRepository _students;
  final GroupRepository _groups;
  final SessionRecordRepository _sessionRecords;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final AcknowledgementRepository _acknowledgements;
  final AssessmentRepository _assessments;
  final SessionRepository _plannedSessions;

  Future<BackupSnapshot> read(ClubSettings settings) async => BackupSnapshot(
    seasons: await _seasons.all(),
    seasonArchives: await _seasonArchives.all(),
    students: await _students.all(),
    groups: await _groups.all(),
    sessionRecords: await _sessionRecords.all(),
    attempts: await _attempts.all(),
    blockAcquisitions: await _acquisitions.all(),
    alertAcknowledgements: await _acknowledgements.all(),
    assessments: await _assessments.all(),
    plannedSessions: await _plannedSessions.getAll(),
    settings: settings,
  );
}

/// Cas d'usage : exporter toutes les données du club en JSON versionné.
@injectable
class ExportBackup {
  ExportBackup(
    SeasonRepository seasons,
    SeasonArchiveRepository seasonArchives,
    StudentRepository students,
    GroupRepository groups,
    SessionRecordRepository sessionRecords,
    AttemptRepository attempts,
    AcquisitionRepository acquisitions,
    AcknowledgementRepository acknowledgements,
    AssessmentRepository assessments,
    SessionRepository plannedSessions,
    this._codec,
    this._clock,
    this._rules,
  ) : _reader = BackupSnapshotReader(
        seasons,
        seasonArchives,
        students,
        groups,
        sessionRecords,
        attempts,
        acquisitions,
        acknowledgements,
        assessments,
        plannedSessions,
      );

  final BackupSnapshotReader _reader;
  final BackupCodec _codec;
  final Clock _clock;
  final RulesStore _rules;

  /// Contenu JSON de la sauvegarde.
  Future<Result<String>> call() => runGuarded(() async {
    final snapshot = await _reader.read(ClubSettings.fromRules(_rules.current));
    return _codec.encode(snapshot, exportedAt: _clock.now());
  });
}
