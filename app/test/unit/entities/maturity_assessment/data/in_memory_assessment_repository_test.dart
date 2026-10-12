import 'package:billard_cfa/entities/maturity_assessment/data/in_memory_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

MaturityAssessment assessment(String id, String student, int dayOfMonth) =>
    MaturityAssessment(
      id: AssessmentId(id),
      studentId: StudentId(student),
      date: day(dayOfMonth),
      concentration: 3,
      endurance: 3,
      frustration: 3,
    );

void main() {
  test('lists the assessments of a student, oldest first', () async {
    final repository = InMemoryAssessmentRepository();
    await repository.add(assessment('late', 's1', 20));
    await repository.add(assessment('early', 's1', 5));
    await repository.add(assessment('other', 's2', 10));

    final found = await repository.forStudent(const StudentId('s1'));

    expect(found.map((a) => a.id.value), ['early', 'late']);
    expect(await repository.forStudent(const StudentId('zz')), isEmpty);
  });
}
