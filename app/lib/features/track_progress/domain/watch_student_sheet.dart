import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/changes.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Les changements des données dont dépend la fiche d'un élève (FB5b) : sa
/// fiche, ses passages, ses blocs acquis, ses « Vu », ses bilans, les séances
/// où il est présent et les groupes. Un événement chaque fois que l'une change,
/// sur cet appareil ou sur un autre ; rien pour l'état de départ.
///
/// La fiche se **recharge** par `GetStudentSheet` : le temps réel ne réécrit
/// aucune règle de calcul, il dit seulement quand relire. Une erreur d'une
/// source (accès retiré) arrive sur le flux ; les autres sources continuent.
@injectable
class WatchStudentSheet {
  WatchStudentSheet(
    this._students,
    this._attempts,
    this._acquisitions,
    this._acknowledgements,
    this._sessions,
    this._groups,
    this._assessments,
  );

  final StudentRepository _students;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final AcknowledgementRepository _acknowledgements;
  final SessionRecordRepository _sessions;
  final GroupRepository _groups;
  final AssessmentRepository _assessments;

  Stream<void> call(StudentId studentId) => changesOf([
    _students.watchById(studentId),
    _attempts.watchForStudent(studentId),
    _acquisitions.watchForStudent(studentId),
    _acknowledgements.watchForStudent(studentId),
    _sessions.watchForStudent(studentId),
    _groups.watchAll(),
    _assessments.watchForStudent(studentId),
  ]);
}
