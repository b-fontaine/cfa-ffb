import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/features/track_group/presentation/bloc/group_overview_cubit.dart';
import 'package:billard_cfa/pages/group_overview/presentation/group_overview_page.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';
import '../../support/sheet_world.dart';
import '../shared/ui/pump_ui.dart';

class _MockOverview extends MockCubit<GroupOverviewState>
    implements GroupOverviewCubit;

void main() {
  late _MockOverview cubit;
  var back = 0;
  StudentId? opened;

  setUp(() {
    cubit = _MockOverview();
    back = 0;
    opened = null;
    when(() => cubit.reload()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, GroupOverviewState state) async {
    whenListen(
      cubit,
      const Stream<GroupOverviewState>.empty(),
      initialState: state,
    );
    await pumpUi(
      tester,
      BlocProvider<GroupOverviewCubit>.value(
        value: cubit,
        child: GroupOverviewPage(
          onBack: () => back++,
          onOpenStudent: (id) => opened = id,
        ),
      ),
    );
  }

  Future<GroupGrid> grid(WidgetTester tester, {bool failing = false}) async {
    final world = SheetWorld();
    await world.start(students: ['s1', 's2']);
    if (failing) {
      await world.passes(ref('a', 1), 1, pass: false);
      await world.passes(ref('a', 1), 1, pass: false, student: 's2');
    }
    return await world.grid(tester);
  }

  testWidgets('shows a loader while loading', (tester) async {
    await pump(tester, const GroupOverviewState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('composes the alerts, the attendance, the grid and the summary', (
    tester,
  ) async {
    final value = await grid(tester, failing: true);
    await pump(
      tester,
      GroupOverviewState(status: GroupOverviewStatus.ready, grid: value),
    );

    expect(find.text('Groupe'), findsOneWidget);
    expect(find.text('Group alerts'), findsOneWidget);
    expect(find.text('Group attendance'), findsOneWidget);
    expect(find.text('Techniques by student'), findsOneWidget);
    expect(find.text('Text summary'), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-cell-a-s1')), findsOneWidget);
  });

  testWidgets('has no group alert section without a group alert', (
    tester,
  ) async {
    final value = await grid(tester);
    await pump(
      tester,
      GroupOverviewState(status: GroupOverviewStatus.ready, grid: value),
    );

    expect(find.text('Group alerts'), findsNothing);
  });

  testWidgets('goes back to the students and opens a student', (tester) async {
    final value = await grid(tester);
    await pump(
      tester,
      GroupOverviewState(status: GroupOverviewStatus.ready, grid: value),
    );

    await tester.tap(find.byKey(const ValueKey('heat-cell-a-s2')));
    await tester.tap(find.text('Students'));

    expect(opened, const StudentId('s2'));
    expect(back, 1);
  });

  testWidgets('a failure proposes to retry', (tester) async {
    await pump(
      tester,
      const GroupOverviewState(
        status: GroupOverviewStatus.failure,
        failure: NotFound('group', 'g1'),
      ),
    );

    await tester.tap(find.text('Retry'));

    verify(() => cubit.reload()).called(1);
  });
}
