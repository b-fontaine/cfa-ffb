import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:injectable/injectable.dart';

/// Exercices validés (par passages ou acquis au positionnement, ADR 0008) de
/// chaque élève suivi par une séance guidée (ADR 0011, décision 2).
///
/// Élèves suivis : les membres du groupe de la séance planifiée à sa date
/// quand le guide en vient ; sinon les élèves dont le public courant est
/// celui du guide. Un groupe inconnu ne suit personne.
@injectable
class LoadValidatedExercises {
  LoadValidatedExercises(
    this._students,
    this._groups,
    this._attempts,
    this._acquisitions,
    this._config,
  );

  final StudentRepository _students;
  final GroupRepository _groups;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final RulesStore _config;

  Future<Map<StudentId, Set<ExerciseRef>>> call({
    required Audience audience,
    required ExerciseCatalogue catalogue,
    ({GroupId id, DateTime on})? group,
  }) async {
    final students = await _students.all();
    final Iterable<Student> followed;
    if (group == null) {
      followed = students.where((s) => s.currentAudience == audience);
    } else {
      final found = await _groups.byId(group.id);
      followed = found == null
          ? const <Student>[]
          : students.where((s) => found.isMemberOn(s.id, group.on));
    }
    final validated = <StudentId, Set<ExerciseRef>>{};
    for (final student in followed) {
      final progress = StudentProgress.derive(
        studentId: student.id,
        attempts: await _attempts.forStudent(student.id),
        acquisitions: await _acquisitions.forStudent(student.id),
        rates: catalogue.rates,
        config: _config.current,
      );
      validated[student.id] = progress.validated;
    }
    return validated;
  }
}
