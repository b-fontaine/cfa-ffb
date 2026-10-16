import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_presentation_view.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/ui/cloth_pattern.dart';
import 'package:billard_cfa/shared/ui/diagram_stage.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/run_sheet_world.dart';
import '../../../../support/session_sheet_fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

void main() {
  RunSheetWorld world({Provenance exercise = Provenance.s}) {
    final sheets = [
      for (final s in catalogueFixture())
        if (s.id.value == 'demi-bille-1')
          s.copyWith(
            illustrations: [
              contactIllustration('contact'),
              contactIllustration('autre'),
            ],
            theorySections: [
              theorySection('t1', illustrations: ['contact', 'autre']),
              theorySection('t2'),
            ],
            exercises: [
              sheetExercise('e1', 1, src: exercise),
              sheetExercise('e2', 2),
            ],
          )
        else
          s,
    ];
    return RunSheetWorld(
      sheets: sheets,
      diagrams: [diagramFixture('entrainement-p05-e1')],
    );
  }

  Future<RunPlan> plan(WidgetTester tester, RunSheetWorld w) async {
    final cubit = (await tester.runAsync(() => w.cubit('demi-bille-1')))!;
    addTearDown(cubit.close);
    return cubit.state.plan!;
  }

  Future<List<String>> pump(
    WidgetTester tester,
    RunPlan plan,
    int step, {
    bool tablet = false,
    Size? size,
    FullscreenState? fullscreen,
  }) async {
    tester.view.physicalSize =
        size ?? (tablet ? const Size(1280, 800) : const Size(400, 800));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <String>[];
    await pumpUi(
      tester,
      RunPresentationView(
        plan: plan,
        step: step,
        onPrevious: () => calls.add('previous'),
        onNext: () => calls.add('next'),
        onClose: () => calls.add('close'),
        fullscreen: fullscreen,
        onToggleFullscreen: fullscreen == null
            ? null
            : () => calls.add('fullscreen'),
      ),
    );
    return calls;
  }

  testWidgets('shows the illustrations of the step with their captions', (
    tester,
  ) async {
    await pump(tester, await plan(tester, world()), 1);

    expect(find.text('Presentation: Section t1'), findsOneWidget);
    expect(find.text('Légende contact'), findsOneWidget);
    expect(find.text('Légende autre'), findsOneWidget);
  });

  testWidgets('shows no note, no rule and no notation', (tester) async {
    await pump(tester, await plan(tester, world()), 1);

    expect(find.textContaining('Set-up:'), findsNothing);
    expect(find.textContaining('Flash question'), findsNothing);
    expect(find.text('Note the results'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows the diagram of an exercise with its caption', (
    tester,
  ) async {
    await pump(tester, await plan(tester, world()), 3);

    expect(find.byType(TableDiagramPlayer), findsOneWidget);
    expect(find.text('Légende du schéma entrainement-p05-e1'), findsOneWidget);
    expect(find.textContaining('Set-up:'), findsNothing);
  });

  testWidgets('keeps the proposal badge on the diagram of a proposal', (
    tester,
  ) async {
    await pump(tester, await plan(tester, world(exercise: Provenance.prop)), 3);

    expect(find.byType(ProposalBadge), findsOneWidget);
  });

  testWidgets('shows no badge for a sourced element', (tester) async {
    await pump(tester, await plan(tester, world()), 1);

    expect(find.byType(ProposalBadge), findsNothing);
  });

  testWidgets('says there is nothing to show for a step without diagram', (
    tester,
  ) async {
    await pump(tester, await plan(tester, world()), 4);

    expect(find.text('Nothing to show for this step.'), findsOneWidget);
    expect(find.byType(TableDiagramPlayer), findsNothing);
  });

  testWidgets('moves between the steps that can be shown and closes', (
    tester,
  ) async {
    final calls = await pump(tester, await plan(tester, world()), 1);

    await tester.tap(find.byTooltip('Next illustration'));
    await tester.tap(find.text('Close'));

    expect(calls, ['next', 'close']);
  });

  testWidgets('disables the move without a step to show on that side', (
    tester,
  ) async {
    await pump(tester, await plan(tester, world()), 1);

    ButtonStyleButton button(String label) => tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

    expect(button('Previous').onPressed, isNull);
    expect(button('Next').onPressed, isNotNull);
    expect(find.byTooltip('Previous illustration'), findsOneWidget);
    expect(find.byTooltip('Next illustration'), findsOneWidget);
  });

  testWidgets('says which illustration is shown among those to show', (
    tester,
  ) async {
    await pump(tester, await plan(tester, world()), 1);

    expect(find.text('Illustration 1 of 2'), findsOneWidget);
  });

  testWidgets('moves with the arrow keys and closes with escape', (
    tester,
  ) async {
    final calls = await pump(tester, await plan(tester, world()), 1);

    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);

    expect(calls, ['next', 'close']);
  });

  testWidgets('moves with a swipe, only where there is a step to show', (
    tester,
  ) async {
    final calls = await pump(tester, await plan(tester, world()), 1);

    await tester.fling(find.byType(Scaffold), const Offset(-300, 0), 1000);
    await tester.fling(find.byType(Scaffold), const Offset(300, 0), 1000);

    expect(calls, ['next']);
  });

  testWidgets('labels the enlarged display for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, await plan(tester, world()), 1);

    expect(
      find.bySemanticsLabel(RegExp('Enlarged display for students')),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('lays out on a landscape tablet without overflow', (
    tester,
  ) async {
    final p = await plan(tester, world());
    for (final step in [0, 1, 3, 5]) {
      await pump(tester, p, step, tablet: true);
      expect(tester.takeException(), isNull, reason: 'étape $step');
    }
  });

  group('stage', () {
    testWidgets('puts a single table diagram on the stage', (tester) async {
      await pump(tester, await plan(tester, world()), 3, tablet: true);

      expect(find.byType(DiagramStage), findsOneWidget);
      expect(find.byType(TableDiagramPlayer), findsOneWidget);
    });

    testWidgets('keeps the column for a step with several illustrations', (
      tester,
    ) async {
      await pump(tester, await plan(tester, world()), 1, tablet: true);

      expect(find.byType(DiagramStage), findsNothing);
      expect(find.text('Légende contact'), findsOneWidget);
      expect(find.text('Légende autre'), findsOneWidget);
    });

    testWidgets('keeps the whole caption above the bar on a tablet (F1)', (
      tester,
    ) async {
      await pump(tester, await plan(tester, world()), 3, tablet: true);

      final caption = tester.getRect(
        find.byKey(const ValueKey('diagram-stage-caption')),
      );
      final bar = tester.getRect(
        find.byKey(const ValueKey('presentation-bottom-bar')),
      );
      expect(caption.bottom, lessThanOrEqualTo(bar.top + 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('puts the cloth pattern behind both kinds of step', (
      tester,
    ) async {
      final p = await plan(tester, world());
      for (final step in [1, 3, 4]) {
        await pump(tester, p, step, tablet: true);
        expect(find.byType(ClothPattern), findsOneWidget, reason: '$step');
      }
    });

    testWidgets('has no height computed from the text any more', (
      tester,
    ) async {
      // La même scène reste correcte quand le texte système grandit : rien
      // n'est mesuré à la main.
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, await plan(tester, world()), 3, tablet: true);

      expect(tester.takeException(), isNull);
    });
  });

  group('full screen', () {
    const supported = FullscreenState(supported: true, active: false);

    testWidgets('offers the button and switches on tap', (tester) async {
      final calls = await pump(
        tester,
        await plan(tester, world()),
        3,
        tablet: true,
        fullscreen: supported,
      );

      await tester.tap(find.text('Full screen'));

      expect(calls, ['fullscreen']);
    });

    testWidgets('says how to leave when active, not by color alone', (
      tester,
    ) async {
      await pump(
        tester,
        await plan(tester, world()),
        3,
        tablet: true,
        fullscreen: const FullscreenState(supported: true, active: true),
      );

      expect(find.text('Exit full screen'), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    });

    testWidgets('tints the active button carpet blue, only when active', (
      tester,
    ) async {
      final p = await plan(tester, world());
      Color? background(Finder inside) => tester
          .widget<ButtonStyleButton>(
            find.ancestor(
              of: inside,
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          )
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{});

      await pump(
        tester,
        p,
        3,
        tablet: true,
        fullscreen: const FullscreenState(supported: true, active: true),
      );
      final scheme = Theme.of(tester.element(find.byType(RunPresentationView)))
          .colorScheme;
      expect(background(find.text('Exit full screen')), scheme.primary);

      await pump(tester, p, 3, tablet: true, fullscreen: supported);
      expect(background(find.text('Full screen')), isNull);

      await pump(
        tester,
        p,
        3,
        size: const Size(320, 640),
        fullscreen: const FullscreenState(supported: true, active: true),
      );
      final iconButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.fullscreen_exit),
      );
      expect(
        iconButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        scheme.primary,
      );
    });

    testWidgets('is hidden when not supported or not wired', (tester) async {
      final p = await plan(tester, world());
      await pump(
        tester,
        p,
        3,
        tablet: true,
        fullscreen: const FullscreenState(supported: false, active: false),
      );
      expect(find.text('Full screen'), findsNothing);

      await pump(tester, p, 3, tablet: true);
      expect(find.text('Full screen'), findsNothing);
    });

    testWidgets('switches with the F key', (tester) async {
      final calls = await pump(
        tester,
        await plan(tester, world()),
        3,
        tablet: true,
        fullscreen: supported,
      );

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);

      expect(calls, ['fullscreen']);
    });

    testWidgets('ignores the F key where the full screen is unavailable', (
      tester,
    ) async {
      final calls = await pump(
        tester,
        await plan(tester, world()),
        3,
        tablet: true,
        fullscreen: const FullscreenState(supported: false, active: false),
      );

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);

      expect(calls, isEmpty);
    });

    testWidgets('shrinks to an icon with a 48 dp target on a phone', (
      tester,
    ) async {
      await pump(
        tester,
        await plan(tester, world()),
        3,
        size: const Size(320, 640),
        fullscreen: supported,
      );

      expect(find.text('Full screen'), findsNothing);
      final button = find.byTooltip('Full screen');
      expect(button, findsOneWidget);
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });
}
