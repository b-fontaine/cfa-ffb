import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/change_audience/domain/audience_change_outcome.dart';
import 'package:billard_cfa/features/change_audience/domain/change_audience.dart';
import 'package:billard_cfa/features/change_audience/presentation/bloc/audience_change_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';

class _MockChangeAudience extends Mock implements ChangeAudience;

void main() {
  late _MockChangeAudience change;
  final today = DateTime(2026, 10, 12);
  const id = StudentId('s1');
  final outcome = AudienceChangeOutcome(
    student: Student.enroll(
      id: id,
      firstName: 'Hugo',
      audience: Audience.children,
      since: DateTime(2026, 9),
    ).changeAudience(Audience.adults, today),
    warnings: const [AudienceChangeWarning.noAssessment],
  );

  setUp(() => change = _MockChangeAudience());

  AudienceChangeBloc build() =>
      AudienceChangeBloc(change, FixedClock(DateTime(2026, 10, 12, 7)));

  blocTest<AudienceChangeBloc, AudienceChangeState>(
    'changes the audience from today with the localised group name',
    build: () {
      when(
        () => change(
          studentId: id,
          audience: Audience.adults,
          effectiveFrom: today,
          groupName: 'Groupe adultes',
        ),
      ).thenAnswer((_) async => Ok(outcome));
      return build();
    },
    act: (bloc) => bloc.add(
      const AudienceChangeEvent.requested(
        studentId: id,
        audience: Audience.adults,
        groupName: 'Groupe adultes',
      ),
    ),
    expect: () => [
      const AudienceChangeState(status: AudienceChangeStatus.saving),
      AudienceChangeState(
        status: AudienceChangeStatus.changed,
        outcome: outcome,
      ),
    ],
  );

  blocTest<AudienceChangeBloc, AudienceChangeState>(
    'reports a refused change',
    build: () {
      when(
        () => change(
          studentId: id,
          audience: Audience.adults,
          effectiveFrom: today,
          groupName: 'g',
        ),
      ).thenAnswer(
        (_) async =>
            const Err(InvariantViolation(InvariantCode.audienceUnchanged)),
      );
      return build();
    },
    act: (bloc) => bloc.add(
      const AudienceChangeEvent.requested(
        studentId: id,
        audience: Audience.adults,
        groupName: 'g',
      ),
    ),
    expect: () => [
      const AudienceChangeState(status: AudienceChangeStatus.saving),
      const AudienceChangeState(
        status: AudienceChangeStatus.failure,
        failure: InvariantViolation(InvariantCode.audienceUnchanged),
      ),
    ],
  );
}
