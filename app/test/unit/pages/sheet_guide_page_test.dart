import 'package:billard_cfa/features/run_sheet/domain/run_mode.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/pages/sheet_guide/presentation/sheet_guide_page.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_fullscreen_controller.dart';
import '../../support/run_sheet_world.dart';
import '../shared/ui/pump_ui.dart';

class _MockCubit extends MockCubit<RunSheetState> implements RunSheetCubit;

class _Calls {
  int back = 0;
  int home = 0;
  final shown = <int>[];
  final recorded = <(ExerciseRef, String, String?)>[];
  int finished = 0;
  final finishedWith = <SessionId?>[];
  final steps = <int>[];
  int exported = 0;
}

void main() {
  Future<_Calls> pump(
    WidgetTester tester,
    RunSheetCubit cubit, {
    FakeFullscreenController? fullscreen,
  }) async {
    final controller = fullscreen ?? FakeFullscreenController();
    addTearDown(controller.close);
    final fullscreenCubit = FullscreenCubit(controller);
    addTearDown(fullscreenCubit.close);
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = _Calls();
    await pumpUi(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<RunSheetCubit>.value(value: cubit),
          BlocProvider<FullscreenCubit>.value(value: fullscreenCubit),
        ],
        child: SheetGuidePage(
          onBack: () => calls.back++,
          onHome: () => calls.home++,
          onShow: calls.shown.add,
          onRecord: (exercise, main, recall) =>
              calls.recorded.add((exercise, main, recall)),
          onFinish: (record) {
            calls.finished++;
            calls.finishedWith.add(record);
          },
          onStepChanged: calls.steps.add,
          onExport: () => calls.exported++,
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

  testWidgets('goes back with the arrow of the compact header', (tester) async {
    final calls = await pump(tester, await real(tester));

    await tester.tap(find.byTooltip('Back'));

    expect(calls.back, 1);
    expect(find.bySubtype<TextButton>(), findsNothing);
  });

  testWidgets('is a full screen without the title bar of the sheet', (
    tester,
  ) async {
    await pump(tester, await real(tester));

    expect(find.text('Quantité demi-bille, session 2/2'), findsNothing);
    expect(find.text('1/7'), findsOneWidget);
  });

  testWidgets('reports the mode chosen from the menu with the current step', (
    tester,
  ) async {
    final cubit = await real(tester, step: 2);
    final calls = await pump(tester, cubit);

    await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Review mode'),
        matching: find.byType(CheckedPopupMenuItem<int>),
      ),
    );
    await tester.pumpAndSettle();

    expect(cubit.state.mode, RunMode.lead);
    expect(calls.steps, [2], reason: 'l’adresse reprend étape et mode');
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
    expect(find.text('1/7'), findsOneWidget);
  });

  testWidgets('reports the step the instructor chose', (tester) async {
    final cubit = await real(tester);
    final calls = await pump(tester, cubit);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(calls.steps, [1]);
    expect(cubit.state.step, 1);
    expect(find.text('2/7'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(calls.finished, 1);
    expect(cubit.state.step, 0);
  });

  testWidgets('ends without a record id when no record was opened', (
    tester,
  ) async {
    final cubit = await real(tester, step: 2);
    final calls = await pump(tester, cubit);

    await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(calls.finishedWith, [null]);
  });

  testWidgets('hands the opened record id to the finish callback', (
    tester,
  ) async {
    final cubit = await real(tester, step: 2);
    cubit.recordChosen(
      recordId: const SessionId('r1'),
      group: const GroupId('g1'),
      date: DateTime(2026, 10, 12),
      absent: const {},
    );
    final calls = await pump(tester, cubit);

    await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(calls.finishedWith, [const SessionId('r1')]);
    expect(cubit.state.recordChoice, isNull);
  });

  testWidgets('records the exercise with the main and the recall blocks', (
    tester,
  ) async {
    final cubit = await real(tester, step: 2);
    final calls = await pump(tester, cubit);

    await tester.ensureVisible(find.text('Note the results'));
    await tester.tap(find.text('Note the results'));

    expect(calls.recorded, [
      (ExerciseRef(blockId: 'demi-bille', number: 3), 'demi-bille', 'posture'),
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
      (ExerciseRef(blockId: 'demi-bille', number: 2), 'demi-bille', 'posture'),
    ]);
  });

  testWidgets('offers the full screen in the menu and switches it', (
    tester,
  ) async {
    final controller = FakeFullscreenController();
    await pump(tester, await real(tester), fullscreen: controller);

    await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full screen'));
    await tester.pumpAndSettle();

    expect(controller.enterCalls, 1);
    await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Exit full screen'), findsOneWidget);
  });

  testWidgets('hides the full screen entry when it is not supported', (
    tester,
  ) async {
    await pump(
      tester,
      await real(tester),
      fullscreen: FakeFullscreenController(supported: false),
    );

    await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Full screen'), findsNothing);
  });

  testWidgets('opens the PDF export from the menu', (tester) async {
    final calls = await pump(tester, await real(tester));

    await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print / export as PDF'));
    await tester.pumpAndSettle();

    expect(calls.exported, 1);
  });
}
