import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/features/assess_maturity/domain/assessment_outcome.dart';
import 'package:billard_cfa/features/assess_maturity/domain/record_assessment.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/bloc/assessment_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';

class _MockRecordAssessment extends Mock implements RecordAssessment;

void main() {
  late _MockRecordAssessment record;
  final today = DateTime(2026, 10, 12);
  const student = StudentId('s1');
  final outcome = AssessmentOutcome(
    assessment: MaturityAssessment(
      id: const AssessmentId('m1'),
      studentId: student,
      date: today,
      concentration: 4,
      endurance: 3,
      frustration: 3,
    ),
    readinessHint: true,
    audience: Audience.children,
  );

  setUp(() => record = _MockRecordAssessment());

  AssessmentBloc build() =>
      AssessmentBloc(record, FixedClock(DateTime(2026, 10, 12, 20)));

  void stub({String? comment, Result<AssessmentOutcome>? result}) => when(
    () => record(
      studentId: student,
      date: today,
      today: today,
      concentration: 4,
      endurance: 3,
      frustration: 3,
      comment: comment,
    ),
  ).thenAnswer((_) async => result ?? Ok(outcome));

  blocTest<AssessmentBloc, AssessmentState>(
    'records the review dated today and keeps the hint',
    build: () {
      stub(comment: 'Calme');
      return build();
    },
    act: (bloc) => bloc.add(
      const AssessmentEvent.submitted(
        studentId: student,
        concentration: 4,
        endurance: 3,
        frustration: 3,
        comment: ' Calme ',
      ),
    ),
    expect: () => [
      const AssessmentState(status: AssessmentStatus.saving),
      AssessmentState(status: AssessmentStatus.saved, outcome: outcome),
    ],
  );

  blocTest<AssessmentBloc, AssessmentState>(
    'drops a blank comment',
    build: () {
      stub();
      return build();
    },
    act: (bloc) => bloc.add(
      const AssessmentEvent.submitted(
        studentId: student,
        concentration: 4,
        endurance: 3,
        frustration: 3,
        comment: '   ',
      ),
    ),
    verify: (bloc) => expect(bloc.state.status, AssessmentStatus.saved),
  );

  blocTest<AssessmentBloc, AssessmentState>(
    'reports a refused review',
    build: () {
      stub(
        result: const Err(InvariantViolation(InvariantCode.scoreOutOfRange)),
      );
      return build();
    },
    act: (bloc) => bloc.add(
      const AssessmentEvent.submitted(
        studentId: student,
        concentration: 4,
        endurance: 3,
        frustration: 3,
      ),
    ),
    expect: () => [
      const AssessmentState(status: AssessmentStatus.saving),
      const AssessmentState(
        status: AssessmentStatus.failure,
        failure: InvariantViolation(InvariantCode.scoreOutOfRange),
      ),
    ],
  );
}
