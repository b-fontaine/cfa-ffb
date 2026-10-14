import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/features/place_student/domain/mark_block_acquired.dart';
import 'package:billard_cfa/features/place_student/domain/revoke_block_acquired.dart';
import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMark extends Mock implements MarkBlockAcquired;

class _MockRevoke extends Mock implements RevokeBlockAcquired;

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 18, 30);
}

void main() {
  late _MockMark mark;
  late _MockRevoke revoke;
  const student = StudentId('s1');
  final placed = DateTime(2026, 10, 5);
  final today = DateTime(2026, 10, 12);

  setUp(() {
    mark = _MockMark();
    revoke = _MockRevoke();
  });

  PlacementBloc build() => PlacementBloc(mark, revoke, _FixedClock());

  Future<Result<BlockAcquisition>> markCall() =>
      mark(studentId: student, blockId: 'posture', date: placed, today: today);

  blocTest<PlacementBloc, PlacementState>(
    'marks the block with today as the upper bound then reports it done',
    build: () {
      when(markCall).thenAnswer(
        (_) async => Ok(
          BlockAcquisition(
            id: const AcquisitionId('a1'),
            studentId: student,
            blockId: 'posture',
            date: placed,
            source: AcquisitionSource.placement,
          ),
        ),
      );
      return build();
    },
    act: (bloc) => bloc.add(
      PlacementEvent.markRequested(
        studentId: student,
        blockId: 'posture',
        date: placed,
      ),
    ),
    expect: () => [
      const PlacementState(
        status: PlacementStatus.working,
        action: PlacementAction.mark,
        blockId: 'posture',
      ),
      const PlacementState(
        status: PlacementStatus.done,
        action: PlacementAction.mark,
        blockId: 'posture',
      ),
    ],
    verify: (_) => verify(markCall).called(1),
  );

  blocTest<PlacementBloc, PlacementState>(
    'refuses a marking with the failure of the use case',
    build: () {
      when(markCall).thenAnswer(
        (_) async => const Err(InvariantViolation(InvariantCode.dateInFuture)),
      );
      return build();
    },
    act: (bloc) => bloc.add(
      PlacementEvent.markRequested(
        studentId: student,
        blockId: 'posture',
        date: placed,
      ),
    ),
    expect: () => [
      const PlacementState(
        status: PlacementStatus.working,
        action: PlacementAction.mark,
        blockId: 'posture',
      ),
      const PlacementState(
        status: PlacementStatus.refused,
        action: PlacementAction.mark,
        blockId: 'posture',
        failure: InvariantViolation(InvariantCode.dateInFuture),
      ),
    ],
  );

  blocTest<PlacementBloc, PlacementState>(
    'revokes the acquired status then reports it done',
    build: () {
      when(() => revoke(studentId: student, blockId: 'posture'))
          .thenAnswer((_) async => const Ok(null));
      return build();
    },
    act: (bloc) => bloc.add(
      const PlacementEvent.revokeRequested(
        studentId: student,
        blockId: 'posture',
      ),
    ),
    expect: () => [
      const PlacementState(
        status: PlacementStatus.working,
        action: PlacementAction.revoke,
        blockId: 'posture',
      ),
      const PlacementState(
        status: PlacementStatus.done,
        action: PlacementAction.revoke,
        blockId: 'posture',
      ),
    ],
  );

  blocTest<PlacementBloc, PlacementState>(
    'refuses a revocation of an unknown marker',
    build: () {
      when(
        () => revoke(studentId: student, blockId: 'posture'),
      ).thenAnswer((_) async => const Err(NotFound('acquisition', 'posture')));
      return build();
    },
    act: (bloc) => bloc.add(
      const PlacementEvent.revokeRequested(
        studentId: student,
        blockId: 'posture',
      ),
    ),
    expect: () => [
      const PlacementState(
        status: PlacementStatus.working,
        action: PlacementAction.revoke,
        blockId: 'posture',
      ),
      const PlacementState(
        status: PlacementStatus.refused,
        action: PlacementAction.revoke,
        blockId: 'posture',
        failure: NotFound('acquisition', 'posture'),
      ),
    ],
  );
}
