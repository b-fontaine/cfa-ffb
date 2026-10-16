import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/features/manage_groups/domain/get_move_options.dart';
import 'package:billard_cfa/features/manage_groups/domain/move_options.dart';
import 'package:billard_cfa/features/manage_groups/domain/move_student.dart';
import 'package:billard_cfa/features/manage_groups/presentation/bloc/move_student_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';

class _MockOptions extends Mock implements GetMoveOptions;

class _MockMove extends Mock implements MoveStudent;

void main() {
  late _MockOptions options;
  late _MockMove move;
  const id = StudentId('s1');
  final today = DateTime(2026, 10, 12);
  const mercredi = GroupChoice(GroupId('g2'), 'Mercredi');
  const loaded = MoveOptions(
    studentId: id,
    firstName: 'Léa',
    current: GroupChoice(GroupId('g1'), 'Jeunes'),
    destinations: [mercredi],
  );

  setUp(() {
    options = _MockOptions();
    move = _MockMove();
  });

  MoveStudentCubit build() =>
      MoveStudentCubit(options, move, FixedClock(DateTime(2026, 10, 12, 9)));

  test('proposes today as the effective day', () {
    expect(build().today, today);
  });

  blocTest<MoveStudentCubit, MoveStudentState>(
    'loads the options',
    build: () {
      when(() => options(studentId: id, today: today))
          .thenAnswer((_) async => const Ok(loaded));
      return build();
    },
    act: (cubit) => cubit.load(id),
    expect: () => [
      const MoveStudentState(),
      const MoveStudentState(status: MoveStudentStatus.ready, options: loaded),
    ],
  );

  blocTest<MoveStudentCubit, MoveStudentState>(
    'reports an unknown student',
    build: () {
      when(() => options(studentId: id, today: today))
          .thenAnswer((_) async => const Err(NotFound('student', 's1')));
      return build();
    },
    act: (cubit) => cubit.load(id),
    expect: () => [
      const MoveStudentState(),
      const MoveStudentState(
        status: MoveStudentStatus.failure,
        failure: NotFound('student', 's1'),
      ),
    ],
  );

  blocTest<MoveStudentCubit, MoveStudentState>(
    'moves the student and names the arrival group',
    build: () {
      when(() => move(studentId: id, toGroupId: mercredi.id, on: today))
          .thenAnswer(
            (_) async => Ok(
              Group(
                id: mercredi.id,
                seasonId: const SeasonId('s'),
                name: 'Mercredi',
                audience: Audience.children,
              ),
            ),
          );
      return build();
    },
    seed: () => const MoveStudentState(
      status: MoveStudentStatus.ready,
      options: loaded,
    ),
    act: (cubit) =>
        cubit.submit(studentId: id, toGroupId: mercredi.id, on: today),
    expect: () => [
      const MoveStudentState(status: MoveStudentStatus.moving, options: loaded),
      const MoveStudentState(
        status: MoveStudentStatus.moved,
        options: loaded,
        movedTo: 'Mercredi',
      ),
    ],
  );

  blocTest<MoveStudentCubit, MoveStudentState>(
    'keeps the sheet open on a refusal',
    build: () {
      when(
        () => move(studentId: id, toGroupId: mercredi.id, on: today),
      ).thenAnswer(
        (_) async =>
            const Err(InvariantViolation(InvariantCode.moveBeforeLastPresence)),
      );
      return build();
    },
    seed: () => const MoveStudentState(
      status: MoveStudentStatus.ready,
      options: loaded,
    ),
    act: (cubit) =>
        cubit.submit(studentId: id, toGroupId: mercredi.id, on: today),
    expect: () => [
      const MoveStudentState(status: MoveStudentStatus.moving, options: loaded),
      const MoveStudentState(
        status: MoveStudentStatus.ready,
        options: loaded,
        failure: InvariantViolation(InvariantCode.moveBeforeLastPresence),
      ),
    ],
  );
}
