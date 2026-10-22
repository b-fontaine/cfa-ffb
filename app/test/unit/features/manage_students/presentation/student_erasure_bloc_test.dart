import 'dart:async';

import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockErasure extends Mock implements StudentErasure;

void main() {
  late _MockErasure erasure;
  const id = StudentId('s1');
  const status = ErasureStatus(
    preview: StudentPurgePreview(attempts: 3),
    inProgress: false,
    synchronized: true,
  );

  setUp(() => erasure = _MockErasure());

  void stubErase(ErasureOutcome outcome) {
    when(
      () => erasure.erase(
        id,
        shouldStop: any(named: 'shouldStop'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => Ok(outcome));
  }

  blocTest<StudentErasureBloc, StudentErasureState>(
    'inspecting reads what will be erased and whether it is already started',
    build: () {
      when(() => erasure.inspect(id)).thenAnswer((_) async => const Ok(status));
      return StudentErasureBloc(erasure);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.inspected(studentId: id)),
    expect: () => [
      const StudentErasureState(
        status: StudentErasureStatus.ready,
        preview: StudentPurgePreview(attempts: 3),
        synchronized: true,
      ),
    ],
  );

  blocTest<StudentErasureBloc, StudentErasureState>(
    'erases the student then reports it',
    build: () {
      stubErase(
        const ErasureOutcome(
          status: OperationRunStatus.completed,
          doneLots: 3,
          totalLots: 3,
        ),
      );
      return StudentErasureBloc(erasure);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.requested(studentId: id)),
    expect: () => [
      const StudentErasureState(status: StudentErasureStatus.working),
      const StudentErasureState(
        status: StudentErasureStatus.erased,
        done: 3,
        total: 3,
      ),
    ],
  );

  blocTest<StudentErasureBloc, StudentErasureState>(
    'a lost connection leaves the erasure to resume, nothing is lost',
    build: () {
      stubErase(
        const ErasureOutcome(
          status: OperationRunStatus.interrupted,
          doneLots: 1,
          totalLots: 4,
          failure: ServiceFailure(ServiceFailureCode.unavailable),
        ),
      );
      return StudentErasureBloc(erasure);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.requested(studentId: id)),
    expect: () => [
      const StudentErasureState(status: StudentErasureStatus.working),
      const StudentErasureState(
        status: StudentErasureStatus.interrupted,
        inProgress: true,
        done: 1,
        total: 4,
        failure: ServiceFailure(ServiceFailureCode.unavailable),
      ),
    ],
  );

  blocTest<StudentErasureBloc, StudentErasureState>(
    'the daily write ceiling pauses the erasure until another day',
    build: () {
      stubErase(
        const ErasureOutcome(
          status: OperationRunStatus.paused,
          doneLots: 2,
          totalLots: 9,
        ),
      );
      return StudentErasureBloc(erasure);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.requested(studentId: id)),
    skip: 1,
    expect: () => [
      const StudentErasureState(
        status: StudentErasureStatus.paused,
        inProgress: true,
        done: 2,
        total: 9,
      ),
    ],
  );

  blocTest<StudentErasureBloc, StudentErasureState>(
    'reports the failure and keeps the student',
    build: () {
      when(
        () => erasure.erase(
          id,
          shouldStop: any(named: 'shouldStop'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => const Err(NotFound('student', 's1')));
      return StudentErasureBloc(erasure);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.requested(studentId: id)),
    expect: () => [
      const StudentErasureState(status: StudentErasureStatus.working),
      const StudentErasureState(
        status: StudentErasureStatus.failure,
        failure: NotFound('student', 's1'),
      ),
    ],
  );

  blocTest<StudentErasureBloc, StudentErasureState>(
    'a failed inspection ends in the failure state with its failure',
    build: () {
      when(() => erasure.inspect(id))
          .thenAnswer((_) async => const Err(NotFound('student', 's1')));
      return StudentErasureBloc(erasure);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.inspected(studentId: id)),
    expect: () => [
      const StudentErasureState(
        status: StudentErasureStatus.failure,
        failure: NotFound('student', 's1'),
      ),
    ],
  );

  blocTest<StudentErasureBloc, StudentErasureState>(
    'the progress of each lot is shown while the erasure runs',
    build: () {
      when(
        () => erasure.erase(
          id,
          shouldStop: any(named: 'shouldStop'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(int, int);
        onProgress(1, 3);
        await Future<void>.delayed(Duration.zero);
        onProgress(2, 3);
        await Future<void>.delayed(Duration.zero);
        return const Ok(
          ErasureOutcome(
            status: OperationRunStatus.completed,
            doneLots: 3,
            totalLots: 3,
          ),
        );
      });
      return StudentErasureBloc(erasure);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.requested(studentId: id)),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      const StudentErasureState(status: StudentErasureStatus.working),
      const StudentErasureState(
        status: StudentErasureStatus.working,
        done: 1,
        total: 3,
      ),
      const StudentErasureState(
        status: StudentErasureStatus.working,
        done: 2,
        total: 3,
      ),
      const StudentErasureState(
        status: StudentErasureStatus.erased,
        done: 3,
        total: 3,
      ),
    ],
  );

  blocTest<StudentErasureBloc, StudentErasureState>(
    'a refused lot ends in the failure state with the failure it reports, '
    'and the erasure stays to resume',
    build: () {
      stubErase(
        const ErasureOutcome(
          status: OperationRunStatus.failed,
          doneLots: 1,
          totalLots: 3,
          failure: ServiceFailure(ServiceFailureCode.denied, 'refus'),
        ),
      );
      return StudentErasureBloc(erasure);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.requested(studentId: id)),
    expect: () => [
      const StudentErasureState(status: StudentErasureStatus.working),
      const StudentErasureState(
        status: StudentErasureStatus.failure,
        inProgress: true,
        done: 1,
        total: 3,
        failure: ServiceFailure(ServiceFailureCode.denied, 'refus'),
      ),
    ],
  );

  test(
    'a stop request is read between two lots and the erasure stops',
    () async {
      final release = Completer<void>();
      late bool Function()? stop;
      when(
        () => erasure.erase(
          id,
          shouldStop: any(named: 'shouldStop'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        stop = invocation.namedArguments[#shouldStop] as bool Function()?;
        await release.future;
        return Ok(
          ErasureOutcome(
            status: stop!()
                ? OperationRunStatus.cancelled
                : OperationRunStatus.completed,
            doneLots: 1,
            totalLots: 4,
          ),
        );
      });
      final bloc = StudentErasureBloc(erasure)
        ..add(const StudentErasureEvent.requested(studentId: id));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const StudentErasureEvent.stopRequested());
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, StudentErasureStatus.stopped);
      expect(bloc.state.inProgress, isTrue);
      await bloc.close();
    },
  );
}
