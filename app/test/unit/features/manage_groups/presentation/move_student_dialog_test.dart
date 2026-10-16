import 'package:billard_cfa/features/manage_groups/domain/move_options.dart';
import 'package:billard_cfa/features/manage_groups/presentation/bloc/move_student_cubit.dart';
import 'package:billard_cfa/features/manage_groups/presentation/ui/move_student_dialog.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../shared/ui/pump_ui.dart';

class _MockCubit extends MockCubit<MoveStudentState>
    implements MoveStudentCubit;

void main() {
  late _MockCubit cubit;
  const id = StudentId('s1');
  const wednesday = GroupChoice(GroupId('g2'), 'Wednesday');
  const loaded = MoveOptions(
    studentId: id,
    firstName: 'Léa',
    destinations: [wednesday],
    current: GroupChoice(GroupId('g1'), 'Kids'),
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    cubit = _MockCubit();
    when(() => cubit.today).thenReturn(DateTime(2026, 10, 12));
    when(
      () => cubit.submit(
        studentId: any(named: 'studentId'),
        toGroupId: any(named: 'toGroupId'),
        on: any(named: 'on'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester,
    MoveStudentState state, {
    Stream<MoveStudentState>? stream,
  }) async {
    whenListen(
      cubit,
      stream ?? const Stream<MoveStudentState>.empty(),
      initialState: state,
    );
    await pumpUi(
      tester,
      BlocProvider<MoveStudentCubit>.value(
        value: cubit,
        child: const MoveStudentDialog(studentId: id),
      ),
    );
  }

  testWidgets('shows a progress indicator while loading', (tester) async {
    await pump(tester, const MoveStudentState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says why the options could not be read', (tester) async {
    await pump(
      tester,
      const MoveStudentState(
        status: MoveStudentStatus.failure,
        failure: NotFound('student', 's1'),
      ),
    );

    expect(find.text('Item not found.'), findsOneWidget);
  });

  testWidgets('names the student, the current group and the targets', (
    tester,
  ) async {
    await pump(
      tester,
      const MoveStudentState(status: MoveStudentStatus.ready, options: loaded),
    );

    expect(find.text('Move Léa to another group'), findsOneWidget);
    expect(find.text('Current group: Kids'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Mon, Oct 12'), findsOneWidget);
  });

  testWidgets('says when the student has no group', (tester) async {
    await pump(
      tester,
      const MoveStudentState(
        status: MoveStudentStatus.ready,
        options: MoveOptions(
          studentId: id,
          firstName: 'Léa',
          destinations: [wednesday],
        ),
      ),
    );

    expect(
      find.text('This student has no group at the moment.'),
      findsOneWidget,
    );
  });

  testWidgets('cannot move before a group is chosen', (tester) async {
    await pump(
      tester,
      const MoveStudentState(status: MoveStudentStatus.ready, options: loaded),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('sends the chosen group and the effective day', (tester) async {
    await pump(
      tester,
      const MoveStudentState(status: MoveStudentStatus.ready, options: loaded),
    );

    await tester.tap(find.text('Wednesday'));
    await tester.pump();
    await tester.tap(find.text('Move'));

    verify(
      () => cubit.submit(
        studentId: id,
        toGroupId: wednesday.id,
        on: DateTime(2026, 10, 12),
      ),
    ).called(1);
  });

  testWidgets('sends another effective day picked in the calendar', (
    tester,
  ) async {
    await pump(
      tester,
      const MoveStudentState(status: MoveStudentStatus.ready, options: loaded),
    );

    await tester.tap(find.text('Wednesday'));
    await tester.tap(find.text('From'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));

    verify(
      () => cubit.submit(
        studentId: id,
        toGroupId: wednesday.id,
        on: DateTime(2026, 10, 14),
      ),
    ).called(1);
  });

  testWidgets('keeps a refusal under the date', (tester) async {
    await pump(
      tester,
      const MoveStudentState(
        status: MoveStudentStatus.ready,
        options: loaded,
        failure: InvariantViolation(InvariantCode.moveBeforeLastPresence),
      ),
    );

    expect(
      find.text(
        'Choose a date after the student’s last session in the current group.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offers no move when no other group exists', (tester) async {
    await pump(
      tester,
      const MoveStudentState(
        status: MoveStudentStatus.ready,
        options: MoveOptions(studentId: id, firstName: 'Léa', destinations: []),
      ),
    );

    expect(
      find.text(
        'There is no other group for this audience in the season. Create one '
        'from the students list.',
      ),
      findsOneWidget,
    );
  });
}
