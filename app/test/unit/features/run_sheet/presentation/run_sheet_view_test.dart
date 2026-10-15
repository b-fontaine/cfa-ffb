import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_sheet_view.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/run_sheet_world.dart';
import '../../../../support/session_sheet_fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

class _Calls {
  final steps = <int>[];
  int shown = 0;
  int finished = 0;
  final recorded = <ExerciseRef>[];
}

void main() {
  Future<(RunSheetCubit, _Calls)> pump(
    WidgetTester tester,
    RunSheetWorld world,
    String sheet, {
    int? step,
    bool tablet = false,
    double textScale = 1,
    bool applyStep = true,
  }) async {
    tester.view.physicalSize = tablet
        ? const Size(1280, 800)
        : const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = (await tester.runAsync(
      () => world.cubit(sheet, step: step),
    ))!;
    addTearDown(cubit.close);
    final calls = _Calls();
    await pumpUi(
      tester,
      MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: BlocProvider.value(
          value: cubit,
          child: BlocBuilder<RunSheetCubit, RunSheetState>(
            builder: (context, state) => RunSheetView(
              state: state,
              onStep: (s) {
                calls.steps.add(s);
                if (applyStep) cubit.showStep(s);
              },
              onShow: () => calls.shown++,
              onFinish: () => calls.finished++,
              onRecord: calls.recorded.add,
            ),
          ),
        ),
      ),
    );
    return (cubit, calls);
  }

  RunSheetWorld world({
    List<String> theoryIllustrations = const [],
    bool initiation = false,
    Provenance exercise = Provenance.s,
  }) {
    final base = catalogueFixture();
    final sheets = [
      for (final s in base)
        if (s.id.value == 'demi-bille-1')
          s.copyWith(
            illustrations: [
              contactIllustration('contact'),
              contactIllustration('jeu'),
              contactIllustration('schema'),
            ],
            theorySections: [
              theorySection('t1', illustrations: ['contact']),
              theorySection('t2', src: Provenance.prop),
            ],
            initiation: [
              if (initiation) ...[
                sheetInitiation('ini', illustration: 'schema'),
                sheetInitiation(
                  'grille',
                  scoring: const Scoring.checklist(
                    criteria: ['Alignement', 'Geste fluide'],
                  ),
                ),
              ],
            ],
            exercises: [
              sheetExercise('e1', 1, src: exercise),
              sheetExercise('e2', 2),
            ],
            game: s.game.copyWith(setupIllustrationId: 'jeu'),
          )
        else
          s,
    ];
    return RunSheetWorld(
      sheets: sheets,
      diagrams: [diagramFixture('entrainement-p05-e1')],
    );
  }

  group('degraded content', () {
    Future<void> pumpState(
      WidgetTester tester,
      RunSheetState Function(RunSheetState ready) change, {
      required int step,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = (await tester.runAsync(
        () => world().cubit('demi-bille-1', step: step),
      ))!;
      addTearDown(cubit.close);
      await pumpUi(
        tester,
        BlocProvider.value(
          value: cubit,
          child: RunSheetView(
            state: change(cubit.state),
            onStep: (_) {},
            onShow: () {},
            onFinish: () {},
            onRecord: (_) {},
          ),
        ),
      );
    }

    testWidgets('says the diagram library is unreadable, not missing', (
      tester,
    ) async {
      await pumpState(
        tester,
        (ready) => ready.copyWith(
          plan: ready.plan!.copyWith(diagrams: {}, diagramsUnreadable: true),
        ),
        step: 3,
      );

      expect(
        find.text('This exercise diagram is invalid and cannot be displayed.'),
        findsOneWidget,
      );
      expect(
        find.text('No diagram is available for this exercise.'),
        findsNothing,
      );
      expect(find.byType(TableDiagramPlayer), findsNothing);
      expect(find.text('Set-up: Mise en place.'), findsOneWidget);
    });

    testWidgets('lists the open points of the session in the review step', (
      tester,
    ) async {
      await pumpState(
        tester,
        (ready) => ready.copyWith(
          plan: ready.plan!.copyWith(
            sheet: ready.plan!.sheet.copyWith(
              uncertainties: ['Le schéma du jeu est incomplet.'],
            ),
          ),
        ),
        step: 7,
      );

      expect(find.text('Open points'), findsOneWidget);
      expect(find.text('Le schéma du jeu est incomplet.'), findsOneWidget);
      expect(
        find.textContaining('saved with “Note the results”'),
        findsOneWidget,
      );
    });

    testWidgets('says a game without a source is a proposal to validate', (
      tester,
    ) async {
      await pumpState(
        tester,
        (ready) => ready.copyWith(
          plan: ready.plan!.copyWith(
            sheet: ready.plan!.sheet.copyWith(
              game: ready.plan!.sheet.game.copyWith(
                sourceGame: null,
                src: Provenance.prop,
              ),
            ),
          ),
        ),
        step: 6,
      );

      expect(
        find.text('Game without a federal source: proposal to validate.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('source:game')),
          matching: find.byType(ProposalBadge),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Game no.'), findsNothing);
    });
  });

  group('theme and notion', () {
    testWidgets('shows the theme with its badge and folds the notion', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1');

      expect(find.text('Theme: Le partage'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('source:theme')),
          matching: find.byType(ProposalBadge),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Notion:'), findsNothing);

      await tapVisible(tester, find.text('Theme: Le partage'));
      await tester.pumpAndSettle();

      expect(find.text('Notion: Viser la tangente.'), findsOneWidget);
      expect(find.text('Un gâteau.'), findsOneWidget);
    });
  });

  group('resume offer', () {
    testWidgets('is shown with both choices when the session was started', (
      tester,
    ) async {
      final (cubit, _) = await pump(tester, world(), 'demi-bille-1', step: 2);
      await tester.runAsync(cubit.syncFromRoute);
      await tester.pump();

      expect(
        find.text('This session is already under way: step 3 of 8.'),
        findsOneWidget,
      );
      expect(find.text('Resume at step 3'), findsOneWidget);
      expect(find.text('Start over'), findsOneWidget);
    });
  });

  group('header', () {
    testWidgets('shows the title, the audience and the step counter', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1');

      expect(find.text('Quantité demi-bille, session 1/2'), findsOneWidget);
      expect(find.text('Children · 90 min'), findsOneWidget);
      expect(find.text('Step 1 of 8'), findsOneWidget);
      expect(find.text('Welcome · 10 min'), findsOneWidget);
    });

    testWidgets('badges the minutes of the phase as a proposal', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1');

      final minutes = find.byKey(const ValueKey('source:minutes'));
      expect(
        find.descendant(of: minutes, matching: find.byType(ProposalBadge)),
        findsOneWidget,
      );
    });

    testWidgets('asks to show the step that has something to show', (
      tester,
    ) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1', step: 1);

      await tapVisible(tester, find.text('Show'));

      expect(calls.shown, 1);
    });

    testWidgets('disables Show on a step with nothing to show', (tester) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1');

      final show = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Show'),
          matching: find.bySubtype<OutlinedButton>(),
        ),
      );
      expect(show.onPressed, isNull);
      expect(calls.shown, 0);
    });

    testWidgets('asks to confirm before ending the session', (tester) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1');

      await tapVisible(tester, find.text('End session'));
      await tester.pumpAndSettle();
      expect(find.text('End the guided session?'), findsOneWidget);
      expect(calls.finished, 0);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.finished, 0);

      await tapVisible(tester, find.text('End session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(calls.finished, 1);
    });
  });

  group('navigation', () {
    testWidgets('goes to the next and previous steps', (tester) async {
      final (cubit, calls) = await pump(tester, world(), 'demi-bille-1');

      await tapVisible(tester, find.text('Next'));
      await tester.pump();
      expect(find.text('Step 2 of 8'), findsOneWidget);
      await tapVisible(tester, find.text('Previous'));
      await tester.pump();

      expect(calls.steps, [1, 0]);
      expect(cubit.state.step, 0);
    });

    testWidgets('disables previous on the first step', (tester) async {
      await pump(tester, world(), 'demi-bille-1');

      final previous = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Previous'),
          matching: find.bySubtype<OutlinedButton>(),
        ),
      );
      expect(previous.onPressed, isNull);
    });

    testWidgets('disables next on the last step', (tester) async {
      await pump(tester, world(), 'demi-bille-1', step: 7);

      final next = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Next'),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      expect(next.onPressed, isNull);
      expect(find.text('Step 8 of 8'), findsOneWidget);
    });

    testWidgets('jumps from the outline and lists every step', (tester) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1');

      await tapVisible(tester, find.text('Outline'));
      await tester.pumpAndSettle();
      expect(find.text('Steps of the session'), findsOneWidget);
      expect(find.text('Section t1'), findsOneWidget);
      expect(find.text('Exercise 2 · Exercice e2'), findsOneWidget);
      await tapVisible(tester, find.text('Jeu'));
      await tester.pumpAndSettle();

      expect(calls.steps, [6]);
      expect(find.text('Steps of the session'), findsNothing);
      expect(find.text('Step 7 of 8'), findsOneWidget);
    });
  });

  group('steps', () {
    testWidgets('recalls the previous session with the flash question', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1');

      expect(find.textContaining('Previous session: Quantité'), findsOneWidget);
      expect(find.text('Flash question: Question ?'), findsOneWidget);
      expect(find.text('Expected answer: Réponse.'), findsOneWidget);
    });

    testWidgets('welcomes instead of recalling for the first session', (
      tester,
    ) async {
      await pump(tester, world(), 'posture-1');

      expect(
        find.text('First session of the catalogue: welcome, no recall.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a theory section with its illustration', (tester) async {
      await pump(tester, world(), 'demi-bille-1', step: 1);

      expect(find.text('Section t1'), findsOneWidget);
      expect(find.text('Une phrase.'), findsOneWidget);
      expect(find.text('To remember: À retenir.'), findsOneWidget);
      expect(find.text('Légende contact'), findsOneWidget);
      expect(find.text('Notion and initiation · 20 min'), findsOneWidget);
    });

    testWidgets('badges a proposed theory section and its illustration', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 2);

      final badge = find.byKey(const ValueKey('source:theory:t2'));
      expect(
        find.descendant(of: badge, matching: find.byType(ProposalBadge)),
        findsOneWidget,
      );
    });

    testWidgets('counts the successes of an initiation locally', (
      tester,
    ) async {
      final (cubit, _) = await pump(
        tester,
        world(initiation: true),
        'demi-bille-1',
        step: 3,
      );

      expect(find.text('0 of 5 successes'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Add a success'));
      await tester.pump();
      expect(find.text('1 of 5 successes'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Remove a success'));
      await tester.pump();

      expect(cubit.state.counts['ini'], 0);
      expect(find.textContaining('Not recorded'), findsOneWidget);
    });

    testWidgets('disables the buttons of the counter at its bounds', (
      tester,
    ) async {
      await pump(tester, world(initiation: true), 'demi-bille-1', step: 3);

      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.bySubtype<IconButton>(),
        ),
      );
      expect(button('Remove a success').onPressed, isNull);
      for (var i = 0; i < 5; i++) {
        await tapVisible(tester, find.byTooltip('Add a success'));
        await tester.pump();
      }

      expect(find.text('5 of 5 successes'), findsOneWidget);
      expect(button('Add a success').onPressed, isNull);
    });

    testWidgets('ticks the criteria of a checklist initiation', (tester) async {
      final (cubit, _) = await pump(
        tester,
        world(initiation: true),
        'demi-bille-1',
        step: 4,
      );

      expect(find.text('0 of 2 criteria acquired'), findsOneWidget);
      await tapVisible(tester, find.text('Alignement'));
      await tester.pump();

      expect(cubit.state.checked['grille'], {0});
      expect(find.text('1 of 2 criteria acquired'), findsOneWidget);
    });

    testWidgets('shows the exercise with its diagram and its notes', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 2 + 1);

      expect(find.text('Exercise 1 · Exercice e1'), findsOneWidget);
      expect(find.text('Exercise 1 of 2'), findsOneWidget);
      expect(find.text('Target: 3 out of 5'), findsOneWidget);
      expect(
        find.text('5 successful passes validate the exercise.'),
        findsOneWidget,
      );
      expect(find.byType(TableDiagramPlayer), findsOneWidget);
      expect(find.text('Set-up: Mise en place.'), findsOneWidget);
      expect(find.text('Instruction: Consigne.'), findsOneWidget);
      expect(find.text('Expected: Attendu.'), findsOneWidget);
      expect(find.text('Hook: Accroche.'), findsOneWidget);
    });

    testWidgets('says the diagram is missing when none is available', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 4);

      expect(find.byType(TableDiagramPlayer), findsNothing);
      expect(
        find.text('No diagram is available for this exercise.'),
        findsOneWidget,
      );
    });

    testWidgets('opens the record of the exercise and says on which block', (
      tester,
    ) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1', step: 3);

      expect(
        find.text('Opens the results screen on “Bloc demi-bille”.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Note the results'));
      await tapVisible(tester, find.text('Note the results'));

      expect(calls.recorded, [ExerciseRef(blockId: 'demi-bille', number: 1)]);
    });

    testWidgets('badges the rate of a proposed exercise', (tester) async {
      await pump(
        tester,
        world(exercise: Provenance.prop),
        'demi-bille-1',
        step: 3,
      );

      expect(
        find.text('This target is a proposal, not a federal figure.'),
        findsOneWidget,
      );
      final badge = find.byKey(const ValueKey('source:exercise:e1'));
      expect(
        find.descendant(of: badge, matching: find.byType(ProposalBadge)),
        findsOneWidget,
      );
    });

    testWidgets('shows the game and keeps its score locally', (tester) async {
      final (cubit, _) = await pump(tester, world(), 'demi-bille-1', step: 6);

      expect(find.text('Jeu'), findsOneWidget);
      expect(find.text('Players: Partie à 2'), findsOneWidget);
      expect(find.text('Légende jeu'), findsOneWidget);
      Future<void> press(String tooltip) async {
        await tester.ensureVisible(find.byTooltip(tooltip));
        await tapVisible(tester, find.byTooltip(tooltip));
        await tester.pump();
      }

      await press('Add a point for Player or team A');
      await press('Add a point for Player or team A');
      await press('Add a point for Player or team B');
      await press('Remove a point for Player or team A');

      expect(cubit.state.scoreA, 1);
      expect(cubit.state.scoreB, 1);
      expect(
        find.text('The score is kept on this screen only: it is not recorded.'),
        findsOneWidget,
      );
    });

    testWidgets('badges the variant and the recall rule of the game', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 6);

      for (final element in ['variant', 'link']) {
        final badge = find.byKey(ValueKey('source:$element'));
        expect(
          find.descendant(of: badge, matching: find.byType(ProposalBadge)),
          findsOneWidget,
          reason: element,
        );
      }
      final game = find.byKey(const ValueKey('source:game'));
      expect(
        find.descendant(of: game, matching: find.byType(ProposalBadge)),
        findsNothing,
      );
    });

    testWidgets('recaps what was counted in the review', (tester) async {
      final (cubit, _) = await pump(
        tester,
        world(initiation: true),
        'demi-bille-1',
      );
      cubit
        ..countChanged('ini', 1)
        ..countChanged('ini', 1)
        ..criterionToggled('grille', 0)
        ..scoreChanged(ScoreSide.a, 2)
        ..scoreChanged(ScoreSide.b, 1)
        ..showStep(9);
      await tester.pump();

      expect(
        find.text('Counted in the guide (cleared when the session ends)'),
        findsOneWidget,
      );
      expect(find.text('Initiation ini: 2 of 5 successes'), findsOneWidget);
      expect(
        find.text('Initiation grille: 1 of 2 criteria acquired'),
        findsOneWidget,
      );
      expect(find.text('Game: 2 – 1'), findsOneWidget);
      expect(find.text('Review question: Question ?'), findsOneWidget);
    });

    testWidgets('says nothing was counted when nothing was', (tester) async {
      await pump(tester, world(), 'demi-bille-1', step: 7);

      expect(find.text('Nothing was counted on this screen.'), findsOneWidget);
    });
  });

  group('timer', () {
    testWidgets('starts and pauses from its buttons', (tester) async {
      final (cubit, _) = await pump(tester, world(), 'demi-bille-1');

      expect(
        find.text('Timer of the phase · 00:00 of about 10 min'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byTooltip('Start the timer'));
      await tester.pump();
      expect(cubit.state.timerRunning, isTrue);
      expect(find.byTooltip('Pause the timer'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Pause the timer'));
      await tester.pump();

      expect(cubit.state.timerRunning, isFalse);
    });

    testWidgets('warns softly under one minute and when over time', (
      tester,
    ) async {
      final w = world();
      final (cubit, _) = await pump(tester, w, 'demi-bille-1');
      cubit.timerToggled();
      await tester.pump();
      expect(find.textContaining('Less than a minute'), findsNothing);

      w.ticker.tick(541);
      await tester.pumpAndSettle();
      expect(
        find.text('Less than a minute left for this phase.'),
        findsOneWidget,
      );

      w.ticker.tick(109);
      await tester.pumpAndSettle();
      expect(find.text('Over the planned time by 00:50.'), findsOneWidget);
    });

    testWidgets('resets the timer', (tester) async {
      final w = world();
      final (cubit, _) = await pump(tester, w, 'demi-bille-1');
      cubit.timerToggled();
      w.ticker.tick(30);
      await tester.pump();

      await tapVisible(tester, find.byTooltip('Reset the timer'));
      await tester.pump();

      expect(cubit.state.timerSeconds, 0);
    });
  });

  group('layout', () {
    testWidgets('puts the diagram next to the text on a landscape tablet', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 3, tablet: true);

      final diagram = tester.getTopLeft(find.byType(TableDiagramPlayer));
      final setup = tester.getTopLeft(find.text('Set-up: Mise en place.'));
      expect(diagram.dx, greaterThan(setup.dx));
      expect(diagram.dy, lessThanOrEqualTo(setup.dy));
    });

    testWidgets('stacks the diagram above the text on a phone', (tester) async {
      await pump(tester, world(), 'demi-bille-1', step: 3);

      final diagram = tester.getTopLeft(find.byType(TableDiagramPlayer));
      final setup = tester.getTopLeft(find.text('Set-up: Mise en place.'));
      expect(diagram.dy, lessThan(setup.dy));
      expect(diagram.dx, setup.dx);
    });

    testWidgets('has touch targets of at least 48 dp', (tester) async {
      await pump(tester, world(initiation: true), 'demi-bille-1', step: 3);

      for (final label in [
        'Previous',
        'Next',
        'Outline',
        'Show',
        'End session',
      ]) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        final size = tester.getSize(button);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
      for (final tooltip in ['Add a success', 'Start the timer']) {
        final size = tester.getSize(find.byTooltip(tooltip));
        expect(size.shortestSide, greaterThanOrEqualTo(48), reason: tooltip);
      }
    });

    testWidgets('keeps every step readable at 200 % text', (tester) async {
      final w = world(initiation: true);
      for (final step in [0, 1, 3, 4, 5, 6, 7, 8]) {
        await pump(tester, w, 'demi-bille-1', step: step, textScale: 2);
        expect(tester.takeException(), isNull, reason: 'étape $step');
      }
    });

    testWidgets('gives an illustration a non-empty semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, world(), 'demi-bille-1', step: 1);

      expect(
        find.bySemanticsLabel(RegExp('Texte alternatif contact')),
        findsWidgets,
      );
      handle.dispose();
    });
  });
}
