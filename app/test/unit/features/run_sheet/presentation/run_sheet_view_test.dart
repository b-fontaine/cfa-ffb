import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_mode.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_sheet_view.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/timer_tone.dart';
import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:billard_cfa/shared/ui/step_app_bar.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/timer_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final modes = <RunMode>[];
  int shown = 0;
  int finished = 0;
  int backs = 0;
  final recorded = <ExerciseRef>[];
}

/// Ouvre le menu ⋮ de l'en-tête.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
  await tester.pumpAndSettle();
}

/// Bouton de la barre basse trouvé par son texte ou, sur téléphone, par son
/// infobulle.
Finder barButton(String label) {
  final bar = find.byKey(const ValueKey('guide-bottom-bar'));
  final byText = find.descendant(of: bar, matching: find.text(label));
  return byText.evaluate().isNotEmpty
      ? byText
      : find.descendant(of: bar, matching: find.byTooltip(label));
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
    Size? size,
  }) async {
    tester.view.physicalSize =
        size ?? (tablet ? const Size(1280, 800) : const Size(400, 800));
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
              onBack: () => calls.backs++,
              onModeChanged: (mode) {
                calls.modes.add(mode);
                cubit.modeChanged(mode);
              },
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
            onBack: () {},
            onModeChanged: (_) {},
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
    testWidgets('shows the step title once, the position and the phase', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 3);

      expect(
        find.descendant(
          of: find.byType(StepAppBar),
          matching: find.text('Exercise 1 · Exercice e1'),
        ),
        findsOneWidget,
      );
      expect(find.text('Exercise 1 · Exercice e1'), findsOneWidget);
      expect(find.text('4/8'), findsOneWidget);
      expect(find.text('Training · 35 min'), findsOneWidget);
      expect(find.byType(PhaseTimeline), findsOneWidget);
    });

    testWidgets('no longer repeats the title and the audience of the sheet', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1');

      expect(find.text('Quantité demi-bille, session 1/2'), findsNothing);
      expect(find.text('Children · 90 min'), findsNothing);
      expect(find.text('Step 1 of 8'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
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

    testWidgets('takes at most a quarter of a phone screen', (tester) async {
      await pump(
        tester,
        world(),
        'demi-bille-1',
        step: 3,
        size: const Size(390, 844),
      );

      final header = tester.getRect(find.byKey(const ValueKey('guide-header')));
      expect(header.top, 0);
      expect(header.bottom, lessThanOrEqualTo(844 / 4));
    });

    testWidgets('asks to show the step that has something to show', (
      tester,
    ) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1', step: 1);

      await tapVisible(tester, find.text('Show'));

      expect(calls.shown, 1);
    });

    testWidgets('hides Show on a step with nothing to show', (tester) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1');

      expect(find.text('Show'), findsNothing);
      expect(calls.shown, 0);
    });

    testWidgets('goes back with the arrow of the header', (tester) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1');

      await tester.tap(find.byTooltip('Back'));

      expect(calls.backs, 1);
    });

    testWidgets('asks to confirm before ending the session from the menu', (
      tester,
    ) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1');

      await openMenu(tester);
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();
      expect(find.text('End the guided session?'), findsOneWidget);
      expect(calls.finished, 0);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.finished, 0);

      await openMenu(tester);
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(calls.finished, 1);
    });

    testWidgets('asks to confirm before finishing from the last step', (
      tester,
    ) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1', step: 7);

      await tester.tap(barButton('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('End the guided session?'), findsOneWidget);
      expect(calls.finished, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.finished, 0);

      await tester.tap(barButton('Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(calls.finished, 1);
    });
  });

  group('phase timeline', () {
    testWidgets('has one entry per phase with the current one marked', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 3);

      final timeline = tester.widget<PhaseTimeline>(find.byType(PhaseTimeline));
      expect(
        [for (final phase in timeline.phases) phase.label],
        ['Welcome', 'Notion', 'Training', 'Game', 'Review'],
      );
      expect(timeline.currentIndex, 2);
    });

    testWidgets('jumps to the first step of the tapped phase', (tester) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1');

      await tester.tap(find.byKey(const ValueKey('phase-3')));
      await tester.pump();
      expect(calls.steps, [3]);
      await tester.tap(find.byKey(const ValueKey('phase-4')));
      await tester.pump();

      expect(calls.steps, [3, 6]);
    });
  });

  group('navigation', () {
    testWidgets('goes to the next and previous steps', (tester) async {
      final (cubit, calls) = await pump(tester, world(), 'demi-bille-1');

      await tapVisible(tester, find.text('Next'));
      await tester.pump();
      expect(find.text('2/8'), findsOneWidget);
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

    testWidgets('offers Finish instead of Next on the last step', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 7);

      expect(find.text('Next'), findsNothing);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('8/8'), findsOneWidget);
    });

    testWidgets('jumps from the outline and lists every step', (tester) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1');

      await openMenu(tester);
      await tester.tap(find.text('Outline'));
      await tester.pumpAndSettle();
      expect(find.text('Steps of the session'), findsOneWidget);
      expect(find.text('Section t1'), findsOneWidget);
      expect(find.text('Exercise 2 · Exercice e2'), findsOneWidget);
      await tapVisible(tester, find.text('Jeu'));
      await tester.pumpAndSettle();

      expect(calls.steps, [6]);
      expect(find.text('Steps of the session'), findsNothing);
      expect(find.text('7/8'), findsOneWidget);
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
    testWidgets('shows the time remaining in the header and toggles', (
      tester,
    ) async {
      final (cubit, _) = await pump(tester, world(), 'demi-bille-1');

      final chip = find.byType(TimerChip);
      expect(chip, findsOneWidget);
      expect(
        tester.getRect(chip).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('guide-header'))).bottom,
        ),
      );
      expect(find.text('10:00'), findsOneWidget);
      expect(find.textContaining('Timer of the phase'), findsNothing);
      await tapVisible(tester, find.byTooltip('Start the timer'));
      await tester.pump();
      expect(cubit.state.timerRunning, isTrue);
      expect(find.byTooltip('Pause the timer'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Pause the timer'));
      await tester.pump();

      expect(cubit.state.timerRunning, isFalse);
    });

    testWidgets('changes tone under one minute and when over time', (
      tester,
    ) async {
      final w = world();
      final (cubit, _) = await pump(tester, w, 'demi-bille-1');
      TimerTone tone() => timerToneFor(
        tester.widget<TimerChip>(find.byType(TimerChip)).remaining,
      );
      cubit.timerToggled();
      await tester.pump();
      expect(tone(), TimerTone.neutral);

      w.ticker.tick(540);
      await tester.pumpAndSettle();
      expect(find.text('01:00'), findsOneWidget);
      expect(tone(), TimerTone.neutral, reason: 'une minute pile : encore bon');
      w.ticker.tick();
      await tester.pumpAndSettle();
      expect(find.text('00:59'), findsOneWidget);
      expect(tone(), TimerTone.attention);

      w.ticker.tick(60);
      await tester.pumpAndSettle();
      expect(find.text('+00:01'), findsOneWidget);
      expect(tone(), TimerTone.overdue);
    });

    testWidgets('vibrates once at each threshold, not every second', (
      tester,
    ) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final w = world();
      final (cubit, _) = await pump(tester, w, 'demi-bille-1');
      cubit.timerToggled();
      await tester.pump();
      w.ticker.tick(500);
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);

      w.ticker.tick(40);
      await tester.pumpAndSettle();
      expect(haptics, isEmpty, reason: '60 s restantes : pas encore');

      w.ticker.tick();
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1), reason: 'seuil de la dernière minute');
      w.ticker.tick(10);
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1), reason: 'pas à chaque seconde');

      w.ticker.tick(49);
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1), reason: '0 s restante : pas dépassé');

      w.ticker.tick();
      await tester.pumpAndSettle();
      expect(haptics, hasLength(2), reason: 'dépassement');
    });

    testWidgets('resets the timer from the menu', (tester) async {
      final w = world();
      final (cubit, _) = await pump(tester, w, 'demi-bille-1');
      cubit.timerToggled();
      w.ticker.tick(30);
      await tester.pump();

      await openMenu(tester);
      await tester.tap(find.text('Reset the timer'));
      await tester.pumpAndSettle();

      expect(cubit.state.timerSeconds, 0);
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('has no reset button of its own any more', (tester) async {
      await pump(tester, world(), 'demi-bille-1');

      expect(find.byIcon(Icons.restart_alt), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('puts the diagram next to the text on a landscape tablet', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 3, tablet: true);

      final diagram = tester.getTopLeft(find.byType(TableDiagramPlayer));
      final setup = tester.getTopLeft(find.text('Set-up: Mise en place.'));
      expect(diagram.dx, lessThan(setup.dx), reason: 'schéma à gauche');
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
      await pump(tester, world(), 'demi-bille-1', step: 3);

      for (final label in ['Previous', 'Note the results', 'Next']) {
        final size = tester.getSize(
          find.ancestor(
            of: barButton(label),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );
        expect(size.shortestSide, greaterThanOrEqualTo(48), reason: label);
      }
      for (final tooltip in ['Back', 'Start the timer', 'More actions']) {
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

    testWidgets('keeps header and bottom bar on a 320 dp screen at 200 %', (
      tester,
    ) async {
      final w = world(initiation: true);
      for (final step in [0, 3, 7]) {
        await pump(
          tester,
          w,
          'demi-bille-1',
          step: step,
          textScale: 2,
          size: const Size(320, 640),
        );
        expect(tester.takeException(), isNull, reason: 'étape $step');
        for (final key in const ['guide-header', 'guide-bottom-bar']) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$key $step');
          expect(rect.right, lessThanOrEqualTo(320), reason: '$key $step');
          expect(rect.bottom, lessThanOrEqualTo(640), reason: '$key $step');
        }
      }
    });

    testWidgets('puts the diagram before the notes and the set-up', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 3);

      final media = tester.getRect(find.byKey(const ValueKey('step-media')));
      expect(
        media.bottom,
        lessThanOrEqualTo(
          tester.getTopLeft(find.text('Set-up: Mise en place.')).dy,
        ),
      );
      expect(
        media.bottom,
        lessThanOrEqualTo(
          tester.getTopLeft(find.text('Target: 3 out of 5')).dy,
        ),
      );
    });

    testWidgets('shows the diagram without scrolling on a phone', (
      tester,
    ) async {
      await pump(
        tester,
        world(),
        'demi-bille-1',
        step: 3,
        size: const Size(390, 844),
      );

      final media = tester.getRect(find.byKey(const ValueKey('step-media')));
      final header = tester.getRect(find.byKey(const ValueKey('guide-header')));
      final bar = tester.getRect(
        find.byKey(const ValueKey('guide-bottom-bar')),
      );
      expect(media.top, greaterThanOrEqualTo(header.bottom));
      expect(media.bottom, lessThanOrEqualTo(bar.top));
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

  group('bottom bar', () {
    List<String> labels(WidgetTester tester) {
      final bar = find.byKey(const ValueKey('guide-bottom-bar'));
      final entries = <(double, double, String)>[];
      for (final element
          in find
              .descendant(
                of: bar,
                matching: find.bySubtype<ButtonStyleButton>(),
              )
              .evaluate()) {
        final finder = find.byElementPredicate((e) => e == element);
        final rect = tester.getRect(finder);
        final text = find.descendant(of: finder, matching: find.byType(Text));
        final tip = find.descendant(of: finder, matching: find.byType(Tooltip));
        entries.add((
          (rect.center.dy / 30).floorToDouble(),
          rect.left,
          text.evaluate().isNotEmpty
              ? tester.widget<Text>(text.first).data!
              : tester.widget<Tooltip>(tip.first).message!,
        ));
      }
      entries.sort((a, b) {
        final byRow = a.$1.compareTo(b.$1);
        return byRow != 0 ? byRow : a.$2.compareTo(b.$2);
      });
      return [for (final entry in entries) entry.$3];
    }

    testWidgets('offers Previous, Note the results and Next on an exercise', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 3, tablet: true);

      expect(labels(tester), ['Previous', 'Note the results', 'Next']);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('puts arrows around Note the results on a phone', (
      tester,
    ) async {
      final (_, calls) = await pump(tester, world(), 'demi-bille-1', step: 3);

      expect(labels(tester), ['Previous', 'Note the results', 'Next']);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.byTooltip('Next'), findsOneWidget);
      await tester.tap(find.byTooltip('Next'));
      await tester.pump();
      expect(calls.steps, [4]);
    });

    testWidgets('offers only Previous and Next on a step without notes', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 1);

      expect(labels(tester), ['Previous', 'Next']);
      expect(find.text('Note the results'), findsNothing);
    });

    testWidgets('stacks full-width buttons at large text on a phone', (
      tester,
    ) async {
      await pump(
        tester,
        world(),
        'demi-bille-1',
        step: 3,
        textScale: 2,
        size: const Size(320, 640),
      );

      expect(labels(tester), ['Note the results', 'Previous', 'Next']);
      expect(find.text('Previous'), findsOneWidget);
    });

    testWidgets('announces its buttons to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, world(), 'demi-bille-1', step: 3);

      // Les flèches sont nommées par leur infobulle (nom accessible).
      for (final name in ['Previous', 'Next']) {
        expect(
          tester.getSemantics(find.byTooltip(name)),
          isSemantics(tooltip: name, isButton: true),
          reason: name,
        );
      }
      expect(find.bySemanticsLabel('Note the results'), findsOneWidget);
      handle.dispose();
    });
  });

  group('modes', () {
    testWidgets('review mode shows the badges and opens the sections', (
      tester,
    ) async {
      final (cubit, _) = await pump(tester, world(), 'demi-bille-1', step: 3);

      expect(cubit.state.mode, RunMode.review);
      expect(find.byType(ProvenanceBadge), findsWidgets);
      expect(find.text('Hook: Accroche.'), findsOneWidget);
      expect(find.text('Hook and challenge'), findsOneWidget);
    });

    testWidgets('lead mode hides every badge and folds the extra sections', (
      tester,
    ) async {
      final (cubit, _) = await pump(
        tester,
        world(exercise: Provenance.prop),
        'demi-bille-1',
        step: 3,
      );
      cubit.modeChanged(RunMode.lead);
      await tester.pump();

      expect(find.byType(ProvenanceBadge), findsNothing);
      expect(find.byType(ProposalBadge), findsNothing);
      expect(
        find.text('This target is a proposal, not a federal figure.'),
        findsNothing,
      );
      // Les sections repliées gardent leur titre, pas leur contenu.
      expect(find.text('Hook and challenge'), findsOneWidget);
      expect(find.text('Hook: Accroche.'), findsNothing);
      expect(find.text('Set-up: Mise en place.'), findsOneWidget);
      expect(find.text('Instruction: Consigne.'), findsOneWidget);
      expect(find.text('Expected: Attendu.'), findsOneWidget);
    });

    testWidgets('lead mode still announces a proposal to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final (cubit, _) = await pump(
        tester,
        world(exercise: Provenance.prop),
        'demi-bille-1',
        step: 3,
      );
      cubit.modeChanged(RunMode.lead);
      await tester.pump();

      expect(find.bySemanticsLabel('Proposal'), findsWidgets);
      handle.dispose();
    });

    testWidgets('lead mode folds the variant, the link and the open points', (
      tester,
    ) async {
      final (cubit, _) = await pump(tester, world(), 'demi-bille-1', step: 6);
      expect(find.textContaining('Playful variant:'), findsOneWidget);
      cubit.modeChanged(RunMode.lead);
      await tester.pump();

      expect(find.text('Playful variant'), findsOneWidget);
      expect(find.textContaining('Playful variant:'), findsNothing);
      expect(find.text('Link with the previous session'), findsOneWidget);
      expect(find.textContaining('Recall rule'), findsNothing);
    });

    testWidgets('toggles the mode from the menu', (tester) async {
      final (cubit, calls) = await pump(tester, world(), 'demi-bille-1');

      await openMenu(tester);
      final entry = find.ancestor(
        of: find.text('Review mode'),
        matching: find.byType(CheckedPopupMenuItem<int>),
      );
      expect(tester.widget<CheckedPopupMenuItem<int>>(entry).checked, isTrue);
      await tester.tap(
        find.ancestor(
          of: find.text('Review mode'),
          matching: find.byType(CheckedPopupMenuItem<int>),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls.modes, [RunMode.lead]);
      expect(cubit.state.mode, RunMode.lead);
      await openMenu(tester);
      expect(
        tester
            .widget<CheckedPopupMenuItem<int>>(
              find.ancestor(
                of: find.text('Review mode'),
                matching: find.byType(CheckedPopupMenuItem<int>),
              ),
            )
            .checked,
        isFalse,
      );
      await tester.tap(
        find.ancestor(
          of: find.text('Review mode'),
          matching: find.byType(CheckedPopupMenuItem<int>),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.modes, [RunMode.lead, RunMode.review]);
    });

    testWidgets('renders the theme at the end of the step in review only', (
      tester,
    ) async {
      final (cubit, _) = await pump(tester, world(), 'demi-bille-1', step: 3);
      final theme = find.text('Theme: Le partage');
      expect(theme, findsOneWidget);
      expect(
        tester.getTopLeft(theme).dy,
        greaterThan(tester.getTopLeft(find.byType(TableDiagramPlayer)).dy),
      );

      cubit.modeChanged(RunMode.lead);
      await tester.pump();

      expect(theme, findsNothing);
    });
  });

  group('session sheet', () {
    testWidgets('gives the title, the audience, the theme and the notion', (
      tester,
    ) async {
      await pump(tester, world(), 'demi-bille-1', step: 3);

      await openMenu(tester);
      await tester.tap(find.text('The session'));
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('session-info'));
      expect(sheet, findsOneWidget);
      for (final text in [
        'Quantité demi-bille, session 1/2',
        'Children · 90 min',
        'Theme: Le partage',
        'Notion: Viser la tangente.',
      ]) {
        expect(
          find.descendant(of: sheet, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });

    testWidgets('counts the proposals of the step', (tester) async {
      await pump(
        tester,
        world(exercise: Provenance.prop),
        'demi-bille-1',
        step: 3,
      );

      await openMenu(tester);
      await tester.tap(find.text('The session'));
      await tester.pumpAndSettle();

      expect(find.text('3 proposals on this step.'), findsOneWidget);
    });
  });
}
