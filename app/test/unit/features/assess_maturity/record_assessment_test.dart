import 'package:billard_cfa/features/assess_maturity/domain/assessment_outcome.dart';
import 'package:billard_cfa/features/assess_maturity/domain/record_assessment.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late RecordAssessment record;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    record = RecordAssessment(
      world.students,
      world.assessments,
      world.ids,
      world.config,
    );
  });

  Future<Result<AssessmentOutcome>> call({
    int concentration = 4,
    int endurance = 4,
    int frustration = 3,
    int dayOfMonth = 10,
    String student = 's1',
    String? comment,
  }) => record(
    studentId: StudentId(student),
    date: day(dayOfMonth),
    today: day(10),
    concentration: concentration,
    endurance: endurance,
    frustration: frustration,
    comment: comment,
  );

  test('stores the comment with the assessment', () async {
    final outcome = ok(await call(comment: 'Se décourage vite'));

    expect(outcome.assessment.comment, 'Se décourage vite');
    final stored = await world.assessments.forStudent(const StudentId('s1'));
    expect(stored.single.comment, 'Se décourage vite');
  });

  test('stores the assessment and gives a readiness hint', () async {
    final outcome = ok(await call());

    expect(outcome.readinessHint, isTrue);
    expect(outcome.assessment.concentration, 4);
    expect(
      await world.assessments.forStudent(const StudentId('s1')),
      hasLength(1),
    );
  });

  test('gives no hint when a criterion is below 3', () async {
    final outcome = ok(await call(endurance: 2));

    expect(outcome.readinessHint, isFalse);
  });

  test('never changes the audience of the student', () async {
    final outcome = ok(await call());

    expect(outcome.audience, Audience.children);
    final student = await world.students.byId(const StudentId('s1'));
    expect(student!.currentAudience, Audience.children);
    expect(student.audienceHistory, hasLength(1));
  });

  test('accepts an assessment dated today', () async {
    expect(await call(), isA<Ok<AssessmentOutcome>>());
  });

  test('refuses an assessment dated after today', () async {
    expect(codeOf(await call(dayOfMonth: 11)), InvariantCode.dateInFuture);
  });

  test('refuses a score outside 1..4 and stores nothing', () async {
    expect(codeOf(await call(frustration: 5)), InvariantCode.scoreOutOfRange);
    expect(await world.assessments.forStudent(const StudentId('s1')), isEmpty);
  });

  test('refuses an unknown student', () async {
    final failure = err(await call(student: 'nope'));

    expect(failure, isA<NotFound>().having((n) => n.kind, 'kind', 'student'));
  });

  test('keeps the history of several assessments', () async {
    await call(dayOfMonth: 5);
    await call(dayOfMonth: 9);

    expect(
      await world.assessments.forStudent(const StudentId('s1')),
      hasLength(2),
    );
  });
}
