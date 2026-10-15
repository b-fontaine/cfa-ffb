import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/pages/sheet_guide/presentation/sheet_guide_page.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/run_sheet_world.dart';
import '../shared/ui/pump_ui.dart';

class _MockCubit extends MockCubit<RunSheetState> implements RunSheetCubit;

class _Calls {
  int back = 0;
  int home = 0;
  final shown = <int>[];
  final recorded = <(ExerciseRef, String, String?, int)>[];
  int finished = 0;
  final steps = <int>[];
}

void main() {
  Future<_Calls> pump(
    WidgetTester tester,
    RunSheetCubit cubit, {
    bool fromPlanner = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = _Calls();
    await pumpUi(
      tester,
      BlocProvider<RunSheetCubit>.value(
        value: cubit,
        child: SheetGuidePage(
          fromPlanner: fromPlanner,
          onBack: () => calls.back++,
          onHome: () => calls.home++,
          onShow: calls.shown.add,
          onRecord: (exercise, main, recall, step) =>
              calls.recorded.add((exercise, main, recall, step)),
          onFinish: () => calls.finished++,
          onStepChanged: calls.steps.add,
        ),
      ),
    );
    return calls;
  }

  Future<RunSheetCubit> real(
    WidgetTester tester, {
    String sheet = 'demi-bille-2',
    int? step,
  }) async {
    final cubit = (await tester.runAsync(
      () => RunSheetWorld().cubit(sheet, step: step),
    ))!;
    addTearDown(cubit.close);
    return cubit;
  }

  testWidgets('shows the loading state', (tester) async {
    final cubit = _MockCubit();
    whenListen(
      cubit,
      const Stream<RunSheetState>.empty(),
      initialState: const RunSheetState(),
    );

    await pump(tester, cubit);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the not found page and leads home', (tester) async {
    final cubit = _MockCubit();
    whenListen(
      cubit,
      const Stream<RunSheetState>.empty(),
      initialState: const RunSheetState(status: RunStatus.notFound),
    );
    final calls = await pump(tester, cubit);

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Back to home'));

    expect(calls.home, 1);
  });

  testWidgets('shows a localized message and retries on failure', (
    tester,
  ) async {
    final cubit = _MockCubit();
    whenListen(
      cubit,
      const Stream<RunSheetState>.empty(),
      initialState: const RunSheetState(
        status: RunStatus.failure,
        failure: InvariantViolation(InvariantCode.invalidSheet),
      ),
    );
    when(cubit.load).thenAnswer((_) async {});
    await pump(tester, cubit);

    await tester.tap(find.text('Retry'));

    verify(cubit.load).called(1);
  });

  testWidgets('goes back to the catalogue session', (tester) async {
    final calls = await pump(tester, await real(tester));

    await tester.tap(find.text('Quantité demi-bille, session 2/2').first);

    expect(calls.back, 1);
  });

  testWidgets('names the planner when the guide was launched from it', (
    tester,
  ) async {
    final calls = await pump(tester, await real(tester), fromPlanner: true);

    await tester.tap(find.text('Planning'));

    expect(calls.back, 1);
    expect(find.text('Quantité demi-bille, session 2/2'), findsOneWidget);
  });

  testWidgets('offers to resume or start over and applies the choice', (
    tester,
  ) async {
    final cubit = await real(tester, step: 2);
    await tester.runAsync(cubit.syncFromRoute);
    final calls = await pump(tester, cubit);
    expect(
      find.text('This session is already under way: step 3 of 7.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Resume at step 3'));
    await tester.pump();

    expect(calls.steps, [2]);
    expect(cubit.state.resumeOffered, isFalse);
    expect(cubit.state.step, 2);
    expect(find.textContaining('already under way'), findsNothing);
  });

  testWidgets('starting over clears the progress', (tester) async {
    final cubit = await real(tester, step: 2);
    await tester.runAsync(cubit.syncFromRoute);
    await pump(tester, cubit);

    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();

    expect(cubit.state.step, 0);
    expect(cubit.state.resumeOffered, isFalse);
    expect(find.text('Step 1 of 7'), findsOneWidget);
  });

  testWidgets('reports the step the instructor chose', (tester) async {
    final cubit = await real(tester);
    final calls = await pump(tester, cubit);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(calls.steps, [1]);
    expect(cubit.state.step, 1);
    expect(find.text('Step 2 of 7'), findsOneWidget);
  });

  testWidgets('shows from the current step', (tester) async {
    final cubit = (await tester.runAsync(
      () =>
          RunSheetWorld(diagrams: [diagramFixture('entrainement-p05-e3')])
              .cubit('demi-bille-2', step: 2),
    ))!;
    addTearDown(cubit.close);
    final calls = await pump(tester, cubit);

    await tester.tap(find.text('Show'));

    expect(calls.shown, [2]);
  });

  testWidgets('ends the session and resets the counters', (tester) async {
    final cubit = await real(tester, step: 2);
    final calls = await pump(tester, cubit);

    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(calls.finished, 1);
    expect(cubit.state.step, 0);
  });

  testWidgets('records the exercise with the recall block and the step', (
    tester,
  ) async {
    final cubit = await real(tester, step: 2);
    final calls = await pump(tester, cubit);

    await tester.ensureVisible(find.text('Note the results'));
    await tester.tap(find.text('Note the results'));

    expect(calls.recorded, [
      (
        ExerciseRef(blockId: 'demi-bille', number: 3),
        'demi-bille',
        'posture',
        2,
      ),
    ]);
  });

  testWidgets('records the recall exercise on its own block as the recall', (
    tester,
  ) async {
    // demi-bille-2 : rappel, théorie, e3, e4, créneau de rappel (étape 4).
    final cubit = await real(tester, step: 4);
    final calls = await pump(tester, cubit);

    await tester.ensureVisible(find.text('Note the results'));
    await tester.tap(find.text('Note the results'));

    // Sans élève suivi : dernier exercice de la séance précédente.
    expect(calls.recorded, [
      (
        ExerciseRef(blockId: 'demi-bille', number: 2),
        'demi-bille',
        'posture',
        4,
      ),
    ]);
  });
}
