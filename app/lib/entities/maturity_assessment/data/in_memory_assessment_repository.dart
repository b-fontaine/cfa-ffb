import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: AssessmentRepository, env: [Environment.test])
class InMemoryAssessmentRepository implements AssessmentRepository {
  final Map<AssessmentId, MaturityAssessment> _assessments = {};

  @override
  Future<void> add(MaturityAssessment assessment) async =>
      _assessments.journaledPut(assessment.id, assessment);

  @override
  Future<List<MaturityAssessment>> forStudent(StudentId studentId) async => [
    for (final assessment in _assessments.values)
      if (assessment.studentId == studentId) assessment,
  ]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<List<MaturityAssessment>> all() async => _assessments.values.toList();

  @override
  Future<void> delete(AssessmentId id) async =>
      _assessments.journaledRemove(id);

  @override
  Future<void> eraseStudent(StudentId studentId) async {
    for (final assessment in _assessments.values.toList()) {
      if (assessment.studentId == studentId) {
        _assessments.journaledRemove(assessment.id);
      }
    }
  }
}
