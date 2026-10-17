import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : effacer physiquement un élève et tout ce qui le nomme
/// (passages, bilans, blocs acquis, acquittements d'alertes, présences,
/// appartenances à un groupe, historique de public) ainsi que l'état des
/// séances guidées en cours qui peuvent en dire quelque chose (ADR 0020 § 7).
/// Données d'élèves mineurs : droit à l'effacement, en fin de saison ou à la
/// demande.
///
/// Tout ou rien (unité de travail). Les séances et les groupes restent, sans
/// l'élève. Les fichiers de sauvegarde déjà exportés ne sont pas touchés :
/// c'est à l'animateur de les supprimer.
@injectable
class EraseStudent {
  EraseStudent(
    this._students,
    this._groups,
    this._sessions,
    this._attempts,
    this._assessments,
    this._acquisitions,
    this._acknowledgements,
    this._runProgress,
    this._plannedSessions,
    this._unitOfWork,
  );

  final StudentRepository _students;
  final GroupRepository _groups;
  final SessionRecordRepository _sessions;
  final AttemptRepository _attempts;
  final AssessmentRepository _assessments;
  final AcquisitionRepository _acquisitions;
  final AcknowledgementRepository _acknowledgements;
  final RunProgressRepository _runProgress;
  final SessionRepository _plannedSessions;
  final UnitOfWork _unitOfWork;

  Future<Result<void>> call(StudentId studentId) => runGuarded(() async {
    if (await _students.byId(studentId) == null) {
      throw NotFound('student', studentId.value);
    }
    await _unitOfWork.run(() => eraseRecords(studentId));
  });

  /// L'enchaînement d'effacement des dépôts nominatifs, **sans** unité de
  /// travail : à appeler dans une unité déjà ouverte (clôture de saison, par
  /// le port `StudentEraser`). L'ordre est celui de la suppression physique.
  Future<void> eraseRecords(StudentId studentId) async {
    // Les séances guidées en cours ne contiennent aucun élève, mais leur score
    // et leurs compteurs sont ceux d'un groupe ou d'une saisie : on les efface
    // par ces liens, **calculés avant** que les appartenances et les présences
    // ne disparaissent. Les groupes, séances planifiées et saisies supprimés
    // logiquement comptent : ils restent en base jusqu'à leur purge.
    final groups = await _groups.idsEverContaining(studentId);
    await _runProgress.eraseLinked(
      groups: groups,
      records: await _sessions.idsEverPresent(studentId),
      plannedSessions: await _plannedSessions.idsOfGroups(groups),
    );
    await _attempts.eraseStudent(studentId);
    await _assessments.eraseStudent(studentId);
    await _acquisitions.eraseStudent(studentId);
    await _acknowledgements.eraseStudent(studentId);
    await _sessions.eraseStudent(studentId);
    await _groups.eraseStudent(studentId);
    await _students.erase(studentId);
  }
}
