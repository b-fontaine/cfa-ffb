import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : effacer physiquement un élève et tout ce qui le nomme
/// (passages, bilans, blocs acquis, présences, appartenances à un groupe,
/// historique de public). Données d'élèves mineurs : droit à l'effacement,
/// en fin de saison ou à la demande.
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
    this._unitOfWork,
  );

  final StudentRepository _students;
  final GroupRepository _groups;
  final SessionRecordRepository _sessions;
  final AttemptRepository _attempts;
  final AssessmentRepository _assessments;
  final AcquisitionRepository _acquisitions;
  final UnitOfWork _unitOfWork;

  Future<Result<void>> call(StudentId studentId) => runGuarded(() async {
    if (await _students.byId(studentId) == null) {
      throw NotFound('student', studentId.value);
    }
    await _unitOfWork.run(() async {
      await _attempts.eraseStudent(studentId);
      await _assessments.eraseStudent(studentId);
      await _acquisitions.eraseStudent(studentId);
      await _sessions.eraseStudent(studentId);
      await _groups.eraseStudent(studentId);
      await _students.erase(studentId);
    });
  });
}
