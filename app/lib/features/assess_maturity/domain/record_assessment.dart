import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/assess_maturity/domain/assessment_outcome.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : enregistrer un bilan de maturité (concentration, endurance,
/// gestion de la frustration). Le bilan aide, il ne décide jamais `[U]`.
@injectable
class RecordAssessment {
  RecordAssessment(this._students, this._assessments, this._ids, this._config);

  final StudentRepository _students;
  final AssessmentRepository _assessments;
  final IdGenerator _ids;
  final RulesConfig _config;

  /// [today] borne la date du bilan (pas de bilan dans le futur).
  Future<Result<AssessmentOutcome>> call({
    required StudentId studentId,
    required DateTime date,
    required DateTime today,
    required int concentration,
    required int endurance,
    required int frustration,
    String? comment,
  }) => runGuarded(() async {
    final student = await _students.byId(studentId);
    if (student == null) throw NotFound('student', studentId.value);
    if (date.isAfter(today)) {
      throw const InvariantViolation(InvariantCode.dateInFuture);
    }
    final assessment = MaturityAssessment(
      id: AssessmentId(_ids.next()),
      studentId: studentId,
      date: date,
      concentration: concentration,
      endurance: endurance,
      frustration: frustration,
      comment: comment,
    );
    await _assessments.add(assessment);
    return AssessmentOutcome(
      assessment: assessment,
      readinessHint: assessment.readinessHint(_config),
      audience: student.currentAudience,
    );
  });
}
