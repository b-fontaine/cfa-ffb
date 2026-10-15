import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : importer une sauvegarde JSON (fusion par identifiant).
///
/// Le contenu est entièrement lu et validé (forme, références, règles métier)
/// avant la première écriture ; les écritures sont ensuite faites dans une
/// unité de travail (transaction SQLite) : un fichier refusé ou une écriture
/// qui échoue ne laisse aucune donnée partielle. Les réglages (format 2) sont
/// écrits dans la même unité de travail ; la valeur courante des règles n'est
/// remplacée qu'après son succès. Un fichier sans réglages les laisse
/// inchangés. Importer deux fois la même sauvegarde est sans effet (les
/// repositories remplacent par identifiant).
@injectable
class ImportBackup {
  ImportBackup(
    this._seasons,
    this._students,
    this._groups,
    this._sessionRecords,
    this._attempts,
    this._acquisitions,
    this._assessments,
    this._plannedSessions,
    this._codec,
    this._rules,
    this._unitOfWork,
    this._settings,
    this._store,
  );

  final SeasonRepository _seasons;
  final StudentRepository _students;
  final GroupRepository _groups;
  final SessionRecordRepository _sessionRecords;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final AssessmentRepository _assessments;
  final SessionRepository _plannedSessions;
  final BackupCodec _codec;
  final BackupRules _rules;
  final UnitOfWork _unitOfWork;
  final SettingsRepository _settings;
  final RulesStore _store;

  Future<Result<ImportSummary>> call(String content) => runGuarded(() async {
    final snapshot = _codec.decode(content);
    await _rules.check(snapshot);
    final settings = snapshot.settings;
    final restored = settings?.applyTo(_store.current);
    await _unitOfWork.run(() async {
      if (settings != null) await _settings.save(settings);
      for (final season in snapshot.seasons) {
        await _seasons.save(season);
      }
      for (final student in snapshot.students) {
        await _students.save(student);
      }
      for (final group in snapshot.groups) {
        await _groups.save(group);
      }
      for (final session in snapshot.sessionRecords) {
        await _sessionRecords.save(session);
      }
      for (final attempt in snapshot.attempts) {
        await _attempts.add(attempt);
      }
      for (final acquisition in snapshot.blockAcquisitions) {
        await _acquisitions.add(acquisition);
      }
      for (final assessment in snapshot.assessments) {
        await _assessments.add(assessment);
      }
      for (final session in snapshot.plannedSessions) {
        await _plannedSessions.add(session);
      }
    });
    if (restored != null) _store.current = restored;
    return ImportSummary.of(snapshot);
  });
}
