import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/features/acknowledge_alert/domain/acknowledge_alert.dart';
import 'package:billard_cfa/features/acknowledge_alert/domain/restore_alert.dart';
import 'package:billard_cfa/features/acknowledge_alert/presentation/bloc/acknowledgement_bloc.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAcknowledge extends Mock implements AcknowledgeAlert;

class _MockRestore extends Mock implements RestoreAlert;

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 18, 30);
}

void main() {
  late _MockAcknowledge acknowledge;
  late _MockRestore restore;
  const student = StudentId('s1');
  final exercise = ExerciseRef(blockId: 'a', number: 1);
  final today = DateTime(2026, 10, 12);

  setUp(() {
    acknowledge = _MockAcknowledge();
    restore = _MockRestore();
  });

  AcknowledgementBloc build() =>
      AcknowledgementBloc(acknowledge, restore, _FixedClock());

  Future<Result<AlertAcknowledgement>> acknowledgeCall() =>
      acknowledge(studentId: student, exercise: exercise, today: today);

  Future<Result<void>> restoreCall() =>
      restore(studentId: student, exercise: exercise);

  blocTest<AcknowledgementBloc, AcknowledgementState>(
    'acknowledges with the day of the injected clock then reports it done',
    build: () {
      when(acknowledgeCall).thenAnswer(
        (_) async => Ok(
          AlertAcknowledgement(
            id: const AcknowledgementId('k1'),
            studentId: student,
            exercise: exercise,
            lastAttemptId: const AttemptId('p3'),
            date: DateTime(2026, 10, 12),
          ),
        ),
      );
      return build();
    },
    act: (bloc) => bloc.add(
      AcknowledgementEvent.acknowledgeRequested(
        studentId: student,
        exercise: exercise,
      ),
    ),
    expect: () => [
      AcknowledgementState(
        status: AcknowledgementStatus.working,
        action: AcknowledgementAction.acknowledge,
        exercise: exercise,
      ),
      AcknowledgementState(
        status: AcknowledgementStatus.done,
        action: AcknowledgementAction.acknowledge,
        exercise: exercise,
      ),
    ],
    verify: (_) => verify(acknowledgeCall).called(1),
  );

  blocTest<AcknowledgementBloc, AcknowledgementState>(
    'reports the failure of a refused acknowledgement',
    build: () {
      when(acknowledgeCall).thenAnswer(
        (_) async =>
            const Err(InvariantViolation(InvariantCode.alertNotActive)),
      );
      return build();
    },
    act: (bloc) => bloc.add(
      AcknowledgementEvent.acknowledgeRequested(
        studentId: student,
        exercise: exercise,
      ),
    ),
    expect: () => [
      AcknowledgementState(
        status: AcknowledgementStatus.working,
        action: AcknowledgementAction.acknowledge,
        exercise: exercise,
      ),
      AcknowledgementState(
        status: AcknowledgementStatus.refused,
        action: AcknowledgementAction.acknowledge,
        exercise: exercise,
        failure: const InvariantViolation(InvariantCode.alertNotActive),
      ),
    ],
  );

  blocTest<AcknowledgementBloc, AcknowledgementState>(
    'restores an alert then reports it done',
    build: () {
      when(restoreCall).thenAnswer((_) async => const Ok(null));
      return build();
    },
    act: (bloc) => bloc.add(
      AcknowledgementEvent.restoreRequested(
        studentId: student,
        exercise: exercise,
      ),
    ),
    expect: () => [
      AcknowledgementState(
        status: AcknowledgementStatus.working,
        action: AcknowledgementAction.restore,
        exercise: exercise,
      ),
      AcknowledgementState(
        status: AcknowledgementStatus.done,
        action: AcknowledgementAction.restore,
        exercise: exercise,
      ),
    ],
    verify: (_) => verify(restoreCall).called(1),
  );

  blocTest<AcknowledgementBloc, AcknowledgementState>(
    'reports the failure of a refused restore',
    build: () {
      when(
        restoreCall,
      ).thenAnswer((_) async => const Err(NotFound('acknowledgement', 'a 1')));
      return build();
    },
    act: (bloc) => bloc.add(
      AcknowledgementEvent.restoreRequested(
        studentId: student,
        exercise: exercise,
      ),
    ),
    expect: () => [
      AcknowledgementState(
        status: AcknowledgementStatus.working,
        action: AcknowledgementAction.restore,
        exercise: exercise,
      ),
      AcknowledgementState(
        status: AcknowledgementStatus.refused,
        action: AcknowledgementAction.restore,
        exercise: exercise,
        failure: const NotFound('acknowledgement', 'a 1'),
      ),
    ],
  );
}
