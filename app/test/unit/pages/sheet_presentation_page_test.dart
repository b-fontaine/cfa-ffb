import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_presentation_cubit.dart';
import 'package:billard_cfa/pages/sheet_presentation/presentation/sheet_presentation_page.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_fullscreen_controller.dart';
import '../../support/run_sheet_world.dart';
import '../../support/session_sheet_fixtures.dart';
import '../shared/ui/pump_ui.dart';

class _MockResolve extends Mock implements ResolveRunPlan;

void main() {
  setUpAll(() => registerFallbackValue(SheetId('x-1')));

  Future<List<int>> pump(
    WidgetTester tester,
    RunPresentationCubit cubit, {
    VoidCallback? onHome,
    FakeFullscreenController? fullscreen,
  }) async {
    final controller = fullscreen ?? FakeFullscreenController();
    addTearDown(controller.close);
    final fullscreenCubit = FullscreenCubit(controller);
    addTearDown(fullscreenCubit.close);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final closed = <int>[];
    await pumpUi(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<RunPresentationCubit>.value(value: cubit),
          BlocProvider<FullscreenCubit>.value(value: fullscreenCubit),
        ],
        child: SheetPresentationPage(
          onClose: closed.add,
          onHome: onHome ?? () {},
        ),
      ),
    );
    return closed;
  }

  Future<RunPresentationCubit> started(
    WidgetTester tester, {
    String sheet = 'demi-bille-1',
    int step = 1,
  }) async {
    final world = RunSheetWorld(
      sheets: [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              illustrations: [contactIllustration('contact')],
              theorySections: [
                theorySection('t1', illustrations: ['contact']),
              ],
            )
          else
            s,
      ],
    );
    final cubit = RunPresentationCubit(world.resolve);
    addTearDown(cubit.close);
    await tester.runAsync(
      () => cubit.started(sheetId: SheetId(sheet), step: step),
    );
    return cubit;
  }

  testWidgets('shows the illustration of the step full screen', (tester) async {
    await pump(tester, await started(tester));

    expect(find.byKey(const ValueKey('presentation')), findsOneWidget);
    expect(find.text('Légende contact'), findsOneWidget);
  });

  testWidgets('closes on the step on display', (tester) async {
    final closed = await pump(tester, await started(tester));

    await tester.tap(find.text('Close'));

    expect(closed, [1]);
  });

  testWidgets('shows the loading state', (tester) async {
    final cubit = RunPresentationCubit(_MockResolve());
    addTearDown(cubit.close);

    await pump(tester, cubit);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the not found page and leads home', (tester) async {
    var home = 0;
    final cubit = await started(tester, sheet: 'inconnue-9');
    await pump(tester, cubit, onHome: () => home++);

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Back to home'));

    expect(home, 1);
  });

  testWidgets('shows a localized message on failure', (tester) async {
    final resolve = _MockResolve();
    when(
      () => resolve(
        any(),
        audience: any(named: 'audience'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer(
      (_) async => const Err(InvariantViolation(InvariantCode.invalidSheet)),
    );
    final cubit = RunPresentationCubit(resolve);
    addTearDown(cubit.close);
    await tester.runAsync(() => cubit.started(sheetId: SheetId('a-1')));

    await pump(tester, cubit);

    expect(find.byType(Text), findsWidgets);
    expect(find.byKey(const ValueKey('presentation')), findsNothing);
    expect(find.text('Page not found'), findsNothing);
  });

  testWidgets('retries after a failure and offers a way back', (tester) async {
    final resolve = _MockResolve();
    var attempts = 0;
    when(
      () => resolve(
        any(),
        audience: any(named: 'audience'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      return const Err(InvariantViolation(InvariantCode.invalidSheet));
    });
    final cubit = RunPresentationCubit(resolve);
    addTearDown(cubit.close);
    await tester.runAsync(
      () => cubit.started(sheetId: SheetId('a-1'), step: 3),
    );
    final closed = await pump(tester, cubit);

    await tester.runAsync(() async {
      await tester.tap(find.text('Retry'));
    });
    await tester.tap(find.text('Back'));

    expect(attempts, 2);
    expect(closed, [0]);
  });

  testWidgets('switches the full screen and keeps it when closing', (
    tester,
  ) async {
    final controller = FakeFullscreenController();
    final closed = await pump(
      tester,
      await started(tester),
      fullscreen: controller,
    );

    await tester.tap(find.text('Full screen'));
    await tester.pump();
    expect(find.text('Exit full screen'), findsOneWidget);
    await tester.tap(find.text('Close'));

    expect(controller.enterCalls, 1);
    expect(controller.exitCalls, 0);
    expect(controller.isActive, isTrue);
    expect(closed, [1]);
  });
}
