import 'dart:math' show Point;

import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_source.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theory.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_detail_view.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/session_sheet_fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

ExerciseDiagram _diagram(String id) => ExerciseDiagram(
  id: id,
  kind: DiagramKind.exercise,
  sheet: 'Fiche',
  caption: 'Légende',
  description: 'Description',
  sourceFile: 'Test.pdf',
  sourcePage: 1,
  table: const DiagramTable(
    balls: [
      TableBall(
        id: 'w',
        color: TableBallColor.white,
        at: Point(2, 2),
        role: TableBallRole.cue,
      ),
    ],
  ),
);

SheetDetail _detail(
  SessionSheet sheet, {
  SessionSheet? previous,
  Map<String, ExerciseSpec> specs = const {},
  Map<String, ExerciseDiagram> diagrams = const {},
  bool unreadable = false,
}) => SheetDetail(
  sheet: sheet,
  partCount: 2,
  previous: previous,
  exerciseSpecs: specs,
  diagrams: diagrams,
  diagramsUnreadable: unreadable,
  timings: {
    for (final audience in Audience.values)
      audience: sheetTiming(
        sheet,
        audience: audience,
        shapes: RulesConfig().shapes,
      ),
  },
);

SheetLink _link(String previous) => SheetLink(
  notionOf: SheetId(previous),
  rule: 'Règle de lien.',
  note: 'Pour rejouer.',
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    SheetDetail detail, {
    Audience audience = Audience.children,
    ValueChanged<Audience>? onAudience,
    Locale locale = const Locale('en'),
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      SingleChildScrollView(
        child: SheetDetailView(
          detail: detail,
          audience: audience,
          onAudienceChanged: onAudience ?? (_) {},
        ),
      ),
      locale: locale,
    );
  }

  testWidgets('says Welcome and the first session note, without a recall', (
    tester,
  ) async {
    await pump(tester, _detail(buildSheet(previous: null, order: 1)));

    expect(find.text('Welcome · 10 min'), findsOneWidget);
    expect(
      find.text('First session of the catalogue: welcome, no recall.'),
      findsOneWidget,
    );
    expect(find.textContaining('Previous session'), findsNothing);
  });

  testWidgets('names the previous session and its flash question', (
    tester,
  ) async {
    final previous = buildSheet(
      technique: 'bille-pleine',
      part: 2,
      order: 8,
      previous: 'bille-pleine-1',
    );
    await pump(tester, _detail(buildSheet(), previous: previous));

    expect(
      find.text('Previous session: Quantité bille-pleine, session 2/2'),
      findsOneWidget,
    );
    expect(find.text('Flash question: Question ?'), findsOneWidget);
    expect(find.text('Expected answer: Réponse.'), findsOneWidget);
    expect(find.text('Recall · 10 min'), findsOneWidget);
  });

  testWidgets('counts the parts of the same technique for the previous', (
    tester,
  ) async {
    final previous = buildSheet();
    final sheet = buildSheet(
      part: 2,
      order: 10,
      previous: 'demi-bille-1',
      exercises: [sheetExercise('e3', 3), sheetExercise('e4', 4)],
    );
    await pump(tester, _detail(sheet, previous: previous));

    expect(
      find.text('Previous session: Quantité demi-bille, session 1/2'),
      findsOneWidget,
    );
  });

  testWidgets('reuses an illustration of the previous session', (tester) async {
    final previous = buildSheet(
      illustrations: [contactIllustration('contact-plein')],
    );
    final sheet = buildSheet(
      part: 2,
      order: 10,
      previous: 'demi-bille-1',
      recall: SheetRecall(
        points: ['Un point.'],
        ask: 'Question ?',
        answer: 'Réponse.',
        src: Provenance.s,
        reuse: SheetReuse(
          sheet: SheetId('demi-bille-1'),
          illustration: 'contact-plein',
        ),
      ),
      exercises: [sheetExercise('e3', 3), sheetExercise('e4', 4)],
    );
    await pump(tester, _detail(sheet, previous: previous));

    expect(find.text('Légende contact-plein'), findsOneWidget);
  });

  testWidgets('shows the theory with its key point, demo and illustration', (
    tester,
  ) async {
    final sheet = buildSheet(
      illustrations: [contactIllustration('contact')],
      theory: [
        SheetTheorySectionBuilder.section(
          'tangente',
          illustrations: ['contact'],
          demo: 'Tirer sans empocher.',
        ),
      ],
    );
    await pump(tester, _detail(sheet));

    expect(find.text('Section tangente'), findsOneWidget);
    expect(find.text('To remember: À retenir.'), findsOneWidget);
    expect(find.text('Demonstration: Tirer sans empocher.'), findsOneWidget);
    expect(find.text('Légende contact'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('source:theory:tangente')),
      findsOneWidget,
    );
  });

  testWidgets('adds the adult extra for adults only', (tester) async {
    final sheet = buildSheet(
      theory: [
        SheetTheorySectionBuilder.section('t1', adultExtra: ['Plus fin.']),
      ],
    );

    await pump(tester, _detail(sheet));
    expect(find.textContaining('For adults'), findsNothing);

    await pump(tester, _detail(sheet), audience: Audience.adults);
    expect(find.text('For adults: Plus fin.'), findsOneWidget);
  });

  testWidgets('hides what has no weight for the audience', (tester) async {
    final sheet = buildSheet(
      theory: [
        theorySection('commun'),
        theorySection('adultes', weight: AudienceWeight(adults: 2)),
      ],
      exercises: [
        sheetExercise('e1', 1),
        sheetExercise('e2', 2, weight: AudienceWeight(adults: 1)),
      ],
    );

    await pump(tester, _detail(sheet));
    expect(find.text('Section commun'), findsOneWidget);
    expect(find.text('Section adultes'), findsNothing);
    expect(find.text('Exercise 1 · Exercice e1'), findsOneWidget);
    expect(find.text('Exercise 2 · Exercice e2'), findsNothing);

    await pump(tester, _detail(sheet), audience: Audience.adults);
    expect(find.text('Section adultes'), findsOneWidget);
    expect(find.text('Exercise 2 · Exercice e2'), findsOneWidget);
  });

  testWidgets('describes a counted initiation as not recorded', (tester) async {
    final sheet = buildSheet(
      illustrations: [contactIllustration('schema')],
      initiation: [
        sheetInitiation('ini', illustration: 'schema'),
        sheetInitiation(
          'grille',
          scoring: const Scoring.checklist(criteria: ['Alignée', 'Immobile']),
        ),
      ],
    );
    await pump(tester, _detail(sheet));

    expect(find.text('Initiation sheet no. 7'), findsNWidgets(2));
    expect(find.text('Count the successes out of 5 attempts.'), findsOneWidget);
    expect(find.text('Criteria to observe: Alignée, Immobile'), findsOneWidget);
    expect(
      find.text('Not recorded in the students’ progress.'),
      findsNWidgets(2),
    );
    expect(find.text('Légende schema'), findsOneWidget);
  });

  testWidgets('reads the rate, the bridge and the bronze from the catalogue', (
    tester,
  ) async {
    final sheet = buildSheet();
    await pump(
      tester,
      _detail(
        sheet,
        specs: {
          'e1': ExerciseSpec(
            ref: ref('demi-bille', 1),
            rate: rate(4, 6),
            bridge: Bridge.frame,
            bronze: true,
          ),
          'e2': ExerciseSpec(
            ref: ref('demi-bille', 2),
            rate: rate(5, 8),
            bridge: Bridge.surface,
          ),
        },
      ),
    );

    expect(find.text('Target: 4 out of 6'), findsOneWidget);
    expect(find.text('Target: 5 out of 8'), findsOneWidget);
    expect(find.text('Bridge on the rail'), findsOneWidget);
    expect(find.text('Bridge on the surface'), findsOneWidget);
    expect(
      find.text('« Bronze billiards » mention on the sheet'),
      findsOneWidget,
    );
    expect(
      find.text('This target is a proposal, not a federal figure.'),
      findsNothing,
    );
  });

  testWidgets('says a proposed exercise rate is a proposal', (tester) async {
    final sheet = buildSheet(
      block: 'posture',
      exercises: [
        sheetExercise('e1', 1, block: 'posture', src: Provenance.prop),
        sheetExercise('e2', 2, block: 'posture'),
      ],
    );
    await pump(tester, _detail(sheet));

    expect(
      find.text('This target is a proposal, not a federal figure.'),
      findsOneWidget,
    );
    final holder = find.byKey(const ValueKey('source:exercise:e1'));
    expect(
      find.descendant(of: holder, matching: find.byType(ProposalBadge)),
      findsOneWidget,
    );
  });

  testWidgets('plays the set-up diagram of an exercise', (tester) async {
    final sheet = buildSheet();
    await pump(
      tester,
      _detail(
        sheet,
        diagrams: {
          'entrainement-p05-e1': _diagram('entrainement-p05-e1'),
          'entrainement-p05-e2': _diagram('entrainement-p05-e2'),
        },
      ),
    );

    expect(find.byType(TableDiagramPlayer), findsNWidgets(2));
    expect(
      find.text('No diagram is available for this exercise.'),
      findsNothing,
    );
  });

  testWidgets('says when a set-up diagram is missing or unreadable', (
    tester,
  ) async {
    await pump(tester, _detail(buildSheet()));
    expect(
      find.text('No diagram is available for this exercise.'),
      findsNWidgets(2),
    );

    await pump(tester, _detail(buildSheet(), unreadable: true));
    expect(
      find.text('This exercise diagram is invalid and cannot be displayed.'),
      findsNWidgets(2),
    );
  });

  testWidgets('lists the mistakes and the playful challenge', (tester) async {
    final sheet = buildSheet(
      exercises: [
        SheetExercise(
          id: 'e1',
          ref: ref('demi-bille', 1),
          diagramId: 'entrainement-p05-e1',
          title: 'Titre',
          weight: AudienceWeight(children: 1, adults: 1),
          setup: 'Poser la rouge.',
          instruction: 'Empocher.',
          expected: 'Demi-bille.',
          mistakes: const [
            SheetMistake(symptom: 'Trop plein', fix: 'Viser plus'),
          ],
          playful: const SheetPlayful(hook: 'Une étoile.', challenge: 'Dix.'),
          passes: 2,
          src: Provenance.s,
        ),
        sheetExercise('e2', 2),
      ],
    );
    await pump(tester, _detail(sheet));

    expect(find.text('Set-up: Poser la rouge.'), findsOneWidget);
    expect(find.text('Instruction: Empocher.'), findsOneWidget);
    expect(find.text('Expected: Demi-bille.'), findsOneWidget);
    expect(find.text('Frequent mistakes (instructor)'), findsOneWidget);
    expect(find.text('Trop plein → Viser plus'), findsOneWidget);
    expect(find.text('Hook: Une étoile.'), findsOneWidget);
    expect(find.text('Challenge: Dix.'), findsOneWidget);
    expect(find.text('2 passes per student'), findsOneWidget);
    expect(find.text('1 pass per student'), findsOneWidget);
    expect(find.byKey(const ValueKey('source:playful:e1')), findsOneWidget);
  });

  testWidgets('describes a federal game, its players and its rules', (
    tester,
  ) async {
    await pump(tester, _detail(buildSheet()));

    expect(find.text('Game no. 7 of the federal sheets'), findsOneWidget);
    expect(find.text('Players: Partie à 2'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Scoring: Score.'), findsOneWidget);
    expect(find.text('End of the game: Fin.'), findsOneWidget);
    expect(find.text('Playful variant: Variante.'), findsOneWidget);
    expect(
      find.text('Recall rule (notion of “Quantité demi-bille”): Règle.'),
      findsNothing,
    );
  });

  testWidgets('says an adapted game is to validate, with its recall rule', (
    tester,
  ) async {
    final previous = buildSheet(
      technique: 'bille-pleine',
      part: 2,
      order: 8,
      previous: 'bille-pleine-1',
    );
    final sheet = buildSheet(
      game:
          sheetGame(
            adapted: true,
            src: Provenance.prop,
            link: _link('bille-pleine-2'),
            setupIllustration: 'schema',
          ).copyWith(
            materials: 'Des jetons.',
            adaptation: const SheetAdaptation(
              children: 'Plus court.',
              adults: 'Plus long.',
            ),
          ),
      illustrations: [contactIllustration('schema')],
    );
    await pump(tester, _detail(sheet, previous: previous));

    expect(
      find.text('Game adapted from game no. 7: adaptation to validate.'),
      findsOneWidget,
    );
    expect(find.text('Equipment: Des jetons.'), findsOneWidget);
    expect(
      find.text(
        'Recall rule (notion of “Quantité bille-pleine”): Règle de lien.',
      ),
      findsOneWidget,
    );
    expect(find.text('Purpose: Pour rejouer.'), findsOneWidget);
    expect(
      find.text('Adaptation for this audience: Plus court.'),
      findsOneWidget,
    );
    expect(find.text('Légende schema'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('source:game')),
        matching: find.byType(ProposalBadge),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the adaptation of the adults for adults', (tester) async {
    final sheet = buildSheet(
      game: sheetGame(link: _link('bille-pleine-2'))
          .copyWith(adaptation: const SheetAdaptation(adults: 'Plus long.')),
    );

    await pump(tester, _detail(sheet));
    expect(find.textContaining('Adaptation for this audience'), findsNothing);

    await pump(tester, _detail(sheet), audience: Audience.adults);
    expect(
      find.text('Adaptation for this audience: Plus long.'),
      findsOneWidget,
    );
  });

  testWidgets('names a game without a federal source', (tester) async {
    final sheet = buildSheet(
      game: sheetGame(
        sourceGame: null,
        src: Provenance.prop,
        link: _link('bille-pleine-2'),
      ),
    );
    await pump(tester, _detail(sheet));

    expect(
      find.text('Game without a federal source: proposal to validate.'),
      findsOneWidget,
    );
  });

  testWidgets('lists the review questions and the sources', (tester) async {
    final sheet = buildSheet(review: const ['Qu’as-tu retenu ?']);
    await pump(tester, _detail(sheet));

    expect(find.text('Review question: Qu’as-tu retenu ?'), findsOneWidget);
    expect(
      find.text('Fiches techniques CFA BàP.pdf, page 15: Fiche 5'),
      findsOneWidget,
    );
    expect(
      find.text(
        'The theme, the playful challenges, the game variant, the recall rule '
        'and the minutes are proposals to validate.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a source without a page and the open points', (
    tester,
  ) async {
    final sheet = buildSheet().copyWith(
      sources: const [
        SheetSourceRef(
          rank: Provenance.ffb,
          file: 'ffbillard.com',
          note: 'Page jeux',
        ),
      ],
      uncertainties: const ['Chevalet à confirmer.'],
    );
    await pump(tester, _detail(sheet));

    expect(find.text('ffbillard.com: Page jeux'), findsOneWidget);
    expect(find.text('ffbillard.com website'), findsOneWidget);
    expect(find.text('Open points'), findsOneWidget);
    expect(find.text('Chevalet à confirmer.'), findsOneWidget);
  });

  testWidgets('flags a session with content to validate, and only then', (
    tester,
  ) async {
    await pump(tester, _detail(buildSheet()));
    expect(find.textContaining('contains unsourced proposals'), findsNothing);
    expect(find.byKey(const ValueKey('review-note')), findsNothing);

    await pump(
      tester,
      _detail(
        buildSheet(
          game: sheetGame(
            adapted: true,
            src: Provenance.prop,
            link: _link('bille-pleine-2'),
          ),
        ),
      ),
    );
    expect(find.textContaining('contains unsourced proposals'), findsOneWidget);
  });

  testWidgets('counts the points to validate and lists each reason', (
    tester,
  ) async {
    await pump(
      tester,
      _detail(
        buildSheet(
          exercises: [sheetExercise('e1', 1, src: Provenance.prop)],
          theory: [theorySection('t1', src: Provenance.prop)],
          game: sheetGame(
            adapted: true,
            src: Provenance.prop,
            link: _link('bille-pleine-2'),
          ),
        ),
      ),
    );

    final note = find.byKey(const ValueKey('review-note'));
    expect(
      find.descendant(of: note, matching: find.text('2 points to validate')),
      findsOneWidget,
    );
    for (final (reason, label) in [
      ('game', 'Game to validate'),
      ('exercise', 'Exercises to validate'),
      ('theory', 'Theory: proposal'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('review-note:$reason')),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: reason,
      );
    }
    expect(find.byKey(const ValueKey('review-note:recall')), findsNothing);
  });

  testWidgets('says 1 point in the singular and in French', (tester) async {
    final sheet = buildSheet(
      exercises: [sheetExercise('e1', 1, src: Provenance.prop)],
    );
    await pump(tester, _detail(sheet));
    expect(find.text('1 point to validate'), findsOneWidget);

    await pump(tester, _detail(sheet), locale: const Locale('fr'));
    expect(find.text('1 point à valider'), findsOneWidget);
  });

  testWidgets('badges the theme and every phase as proposals', (tester) async {
    await pump(tester, _detail(buildSheet()));

    expect(find.byKey(const ValueKey('source:theme')), findsOneWidget);
    expect(find.byKey(const ValueKey('source:minutes')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('source:theme')),
        matching: find.byType(ProposalBadge),
      ),
      findsOneWidget,
    );
  });

  testWidgets('switches the audience from the chips', (tester) async {
    Audience? chosen;
    await pump(tester, _detail(buildSheet()), onAudience: (a) => chosen = a);

    expect(find.text('90 min in total (approximate)'), findsOneWidget);
    await tester.tap(find.text('Adults · 120 min'));

    expect(chosen, Audience.adults);
  });

  testWidgets('keeps the illustrations of a proposal theory badged', (
    tester,
  ) async {
    final sheet = buildSheet(
      illustrations: [contactIllustration('contact')],
      theory: [
        SheetTheorySectionBuilder.section(
          'glose',
          illustrations: ['contact'],
          src: Provenance.prop,
        ),
      ],
    );
    await pump(tester, _detail(sheet));

    // Badge de la section + badge de l'illustration + badges de phase (5)
    // + thème + minutes + « à valider » + jeu sans proposition : l'illustration
    // d'un élément [Prop] porte le sien.
    final illustration = find.ancestor(
      of: find.text('Légende contact'),
      matching: find.byType(Column),
    );
    expect(
      find.descendant(
        of: illustration.first,
        matching: find.byType(ProposalBadge),
      ),
      findsOneWidget,
    );
  });

  group('phase timeline', () {
    testWidgets('replaces the Jump to chips', (tester) async {
      await pump(tester, _detail(buildSheet()));

      expect(find.byType(PhaseTimeline), findsOneWidget);
      expect(find.text('Jump to'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('sits under the audience choice and its total', (tester) async {
      await pump(tester, _detail(buildSheet()));

      final total = tester.getBottomLeft(
        find.text('90 min in total (approximate)'),
      );
      final timeline = tester.getTopLeft(find.byType(PhaseTimeline));
      final firstPhase = tester.getTopLeft(
        find.byKey(const ValueKey('phase:welcome')),
      );
      expect(timeline.dy, greaterThanOrEqualTo(total.dy));
      expect(firstPhase.dy, greaterThan(timeline.dy));
      expect(
        tester.getTopLeft(find.text('Adults · 120 min')).dy,
        lessThan(timeline.dy),
      );
    });

    testWidgets('shows the five phases with their minutes for the audience', (
      tester,
    ) async {
      await pump(tester, _detail(buildSheet()));
      PhaseTimeline timeline() =>
          tester.widget<PhaseTimeline>(find.byType(PhaseTimeline));

      expect(timeline().phases.map((p) => p.label), [
        'Recall',
        'Theory',
        'Exercises',
        'Game',
        'Review',
      ]);
      expect(timeline().phases.fold<int>(0, (sum, p) => sum + p.minutes), 90);
      expect(timeline().currentIndex, -1);

      await pump(tester, _detail(buildSheet()), audience: Audience.adults);
      expect(timeline().phases.fold<int>(0, (sum, p) => sum + p.minutes), 120);
    });

    testWidgets('starts with Welcome on the first session', (tester) async {
      await pump(tester, _detail(buildSheet(previous: null, order: 1)));

      final timeline = tester.widget<PhaseTimeline>(find.byType(PhaseTimeline));
      expect(timeline.phases.first.label, 'Welcome');
    });

    testWidgets('jumps to a phase when a segment is tapped', (tester) async {
      await pump(tester, _detail(buildSheet()));
      final review = find.byKey(const ValueKey('phase:review'));
      // La séance est plus haute que l'écran : le bilan est hors écran.
      expect(tester.getTopLeft(review).dy, greaterThan(1200));

      await tester.tap(find.byKey(const ValueKey('phase-5')));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(review).dy, lessThan(1200));
    });

    testWidgets('jumps without animation when reduced motion is on', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpUi(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            size: Size(800, 1200),
          ),
          child: SingleChildScrollView(
            child: SheetDetailView(
              detail: _detail(buildSheet()),
              audience: Audience.children,
              onAudienceChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('phase-4')));
      await tester.pump();

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('phase:game'))).dy,
        lessThan(1200),
      );
    });

    testWidgets('keeps its segments at 48 dp on 320 dp with text at 200 %', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, _detail(buildSheet()), width: 320);

      expect(tester.takeException(), isNull);
      for (var i = 1; i <= 5; i++) {
        final size = tester.getSize(find.byKey(ValueKey('phase-$i')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('exercise card layout', () {
    SheetDetail withDiagram() => _detail(
      buildSheet(exercises: [sheetExercise('e1', 1), sheetExercise('e2', 2)]),
      diagrams: {
        'entrainement-p05-e1': _diagram('entrainement-p05-e1'),
        'entrainement-p05-e2': _diagram('entrainement-p05-e2'),
      },
    );

    Rect box(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(ValueKey(key)));

    testWidgets('puts the diagram left of the text from 720 dp', (
      tester,
    ) async {
      await pump(tester, withDiagram(), width: 720);

      final visual = box(tester, 'exercise-visual:e1');
      final text = box(tester, 'exercise-text:e1');
      expect(visual.right, lessThanOrEqualTo(text.left));
      expect((visual.top - text.top).abs(), lessThan(1));
      expect(find.byType(TableDiagramPlayer), findsWidgets);
    });

    testWidgets('stacks the text under the diagram under 720 dp', (
      tester,
    ) async {
      await pump(tester, withDiagram(), width: 719);

      final visual = box(tester, 'exercise-visual:e1');
      final text = box(tester, 'exercise-text:e1');
      expect(text.top, greaterThanOrEqualTo(visual.bottom));
    });

    testWidgets('keeps the same content in both layouts', (tester) async {
      await pump(tester, withDiagram(), width: 719);
      final narrow = find.text('Set-up: Mise en place.').evaluate().length;
      await pump(tester, withDiagram(), width: 1000);
      final wide = find.text('Set-up: Mise en place.').evaluate().length;

      expect(narrow, wide);
      expect(wide, 2);
    });

    testWidgets('puts the missing-diagram message on the left too', (
      tester,
    ) async {
      await pump(tester, _detail(buildSheet()), width: 900);

      final visual = box(tester, 'exercise-visual:e1');
      final text = box(tester, 'exercise-text:e1');
      expect(visual.right, lessThanOrEqualTo(text.left));
    });

    testWidgets('caps the text blocks at 760 dp and lets only the exercise '
        'cards use the width on 1280 dp', (tester) async {
      await pump(tester, withDiagram(), width: 1280);

      expect(tester.getSize(find.byType(PhaseTimeline)).width, 760);
      final visual = box(tester, 'exercise-visual:e1');
      final text = box(tester, 'exercise-text:e1');
      expect(text.right - visual.left, greaterThan(760));
    });

    testWidgets('does not overflow on 720 dp with text at 200 %', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, withDiagram(), width: 720);

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('has no input field or edit button', (tester) async {
    await pump(tester, _detail(buildSheet()));

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.textContaining('Read-only'), findsNothing);
  });

  testWidgets('is written in French under the French interface', (
    tester,
  ) async {
    await pump(tester, _detail(buildSheet()), locale: const Locale('fr'));

    expect(find.text('Rappel · 10 min'), findsOneWidget);
    expect(find.text('Jeu · 20 min'), findsOneWidget);
    expect(find.text('Enfants · 90 min'), findsOneWidget);
    expect(find.textContaining('rédigé en français'), findsNothing);
  });

  test('contact fractions and tip points are exercised by the fixtures', () {
    // Garde-fou de lisibilité : la fixture d'illustration utilise des valeurs
    // valides du FORMAT.
    final i = contactIllustration('x') as ContactIllustration;
    expect(i.fraction, ContactFraction.half);
    expect(i.tipPoint, TipPoint.center);
    expect(rate(), SuccessRate(successes: 3, attempts: 5));
  });
}

/// Section de théorie avec champs facultatifs (la fixture partagée ne porte
/// pas `adultExtra` ni `demo`).
abstract final class SheetTheorySectionBuilder {
  static SheetTheorySection section(
    String id, {
    List<String> illustrations = const [],
    List<String> adultExtra = const [],
    String? demo,
    Provenance src = Provenance.s,
  }) => SheetTheorySection(
    id: id,
    title: 'Section $id',
    weight: AudienceWeight(children: 1, adults: 1),
    body: const ['Une phrase.'],
    keyPoint: 'À retenir.',
    illustrationIds: illustrations,
    adultExtra: adultExtra,
    demo: demo,
    src: src,
  );
}
