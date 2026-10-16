import 'package:billard_cfa/features/track_progress/domain/list_watched_students.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_list.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/watched_students_cubit.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockList extends Mock implements ListWatchedStudents;

void main() {
  late _MockList list;
  const watchList = WatchList(total: 7);

  setUp(() => list = _MockList());

  blocTest<WatchedStudentsCubit, WatchedStudentsState>(
    'loads the students to watch',
    setUp: () =>
        when(() => list()).thenAnswer((_) async => const Ok(watchList)),
    build: () => WatchedStudentsCubit(list),
    act: (cubit) => cubit.load(),
    expect: () => [
      const WatchedStudentsState(
        status: WatchedStatus.ready,
        watchList: watchList,
      ),
    ],
  );

  blocTest<WatchedStudentsCubit, WatchedStudentsState>(
    'reports a failure without losing the section',
    setUp: () => when(
      () => list(),
    ).thenAnswer((_) async => const Err<WatchList>(NotFound('student', 'x'))),
    build: () => WatchedStudentsCubit(list),
    act: (cubit) => cubit.load(),
    expect: () => [
      const WatchedStudentsState(
        status: WatchedStatus.failure,
        failure: NotFound('student', 'x'),
      ),
    ],
  );

  blocTest<WatchedStudentsCubit, WatchedStudentsState>(
    'shows loading again on retry',
    setUp: () =>
        when(() => list()).thenAnswer((_) async => const Ok(watchList)),
    build: () => WatchedStudentsCubit(list),
    seed: () => const WatchedStudentsState(
      status: WatchedStatus.failure,
      failure: NotFound('student', 'x'),
    ),
    act: (cubit) => cubit.load(),
    expect: () => [
      const WatchedStudentsState(),
      const WatchedStudentsState(
        status: WatchedStatus.ready,
        watchList: watchList,
      ),
    ],
  );
}
