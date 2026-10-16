import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/run_sheet/domain/recall_exercise.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/session_sheet_fixtures.dart';

ExerciseDiagram _diagram(String id) => ExerciseDiagram(
  id: id,
  kind: DiagramKind.exercise,
  sheet: 'Fiche',
  caption: 'Légende',
  description: 'Description',
  sourceFile: 'Test.pdf',
  sourcePage: 1,
  table: const DiagramTable(balls: []),
);

final _link = SheetLink(
  notionOf: SheetId('bille-pleine-2'),
  rule: 'Règle.',
  note: 'Note.',
);

RunPlan _plan({
  Provenance recall = Provenance.s,
  Provenance exercise = Provenance.s,
  Map<String, ExerciseDiagram> diagrams = const {},
}) {
  final previous = buildSheet(
    technique: 'bille-pleine',
    part: 2,
    order: 8,
    previous: 'bille-pleine-1',
    block: 'bille-pleine',
    illustrations: [contactIllustration('contact-plein')],
    exercises: [
      sheetExercise('e3', 3, block: 'bille-pleine'),
      sheetExercise('e4', 4, block: 'bille-pleine'),
    ],
  );
  final sheet = buildSheet(
    recall: buildSheet().recall.copyWith(src: recall),
    theory: [
      theorySection('t1', illustrations: ['contact']),
      theorySection('t2'),
    ],
    initiation: [sheetInitiation('i1', illustration: 'schema')],
    illustrations: [
      contactIllustration('contact'),
      contactIllustration('schema'),
      contactIllustration('jeu'),
    ],
    exercises: [
      sheetExercise('e1', 1, src: exercise),
      sheetExercise('e2', 2),
    ],
    game: sheetGame(setupIllustration: 'jeu', link: _link),
  );
  return RunPlan(
    sheet: sheet,
    audience: Audience.children,
    partCount: 2,
    timing: sheetTiming(
      sheet,
      audience: Audience.children,
      shapes: RulesConfig().shapes,
    ),
    steps: const [
      RunStep(
        kind: RunStepKind.recall,
        phase: SessionPhase.welcome,
        minutes: 10,
      ),
      RunStep(
        kind: RunStepKind.theory,
        phase: SessionPhase.notionAndInitiation,
        minutes: 5,
        elementId: 't1',
      ),
      RunStep(
        kind: RunStepKind.theory,
        phase: SessionPhase.notionAndInitiation,
        minutes: 5,
        elementId: 't2',
      ),
      RunStep(
        kind: RunStepKind.initiation,
        phase: SessionPhase.notionAndInitiation,
        minutes: 10,
        elementId: 'i1',
      ),
      RunStep(
        kind: RunStepKind.exercise,
        phase: SessionPhase.training,
        minutes: 20,
        elementId: 'e1',
      ),
      RunStep(
        kind: RunStepKind.exercise,
        phase: SessionPhase.training,
        minutes: 15,
        elementId: 'e2',
      ),
      RunStep(kind: RunStepKind.game, phase: SessionPhase.game, minutes: 20),
      RunStep(kind: RunStepKind.review, phase: SessionPhase.review, minutes: 5),
    ],
    passesRequired: 5,
    previous: previous,
    diagrams: diagrams,
  );
}

void main() {
  test('counts the steps and clamps a step into the range', () {
    final plan = _plan();

    expect(plan.stepCount, 8);
    expect(plan.clamp(-3), 0);
    expect(plan.clamp(4), 4);
    expect(plan.clamp(99), 7);
  });

  test('finds the first step of a phase', () {
    final plan = _plan();

    expect(plan.firstStepOf(SessionPhase.welcome), 0);
    expect(plan.firstStepOf(SessionPhase.training), 4);
    expect(plan.firstStepOf(SessionPhase.review), 7);
  });

  test('lists the phases of the session in the order of its steps', () {
    expect(_plan().phases, [
      SessionPhase.welcome,
      SessionPhase.notionAndInitiation,
      SessionPhase.training,
      SessionPhase.game,
      SessionPhase.review,
    ]);
    expect(_plan().copyWith(steps: const []).phases, isEmpty);
  });

  test('gives the position of the phase of a step', () {
    final plan = _plan();

    expect(plan.phaseIndexOf(0), 0);
    expect(plan.phaseIndexOf(2), 1);
    expect(plan.phaseIndexOf(5), 2);
    expect(plan.phaseIndexOf(7), 4);
    expect(plan.phaseIndexOf(99), 4, reason: 'ramené dans la plage');
  });

  test('counts the proposals a step carries, minutes included', () {
    final plan = _plan(exercise: Provenance.prop);

    // Minutes de la phase (toujours une proposition) + la source de l'élément
    // + l'accroche ludique d'un exercice (toujours une proposition).
    expect(plan.proposalCountOf(plan.steps[4]), 3, reason: 'exercice [Prop]');
    expect(plan.proposalCountOf(plan.steps[5]), 2, reason: 'exercice [S]');
    expect(plan.proposalCountOf(plan.steps[0]), 1, reason: 'rappel [S]');
    expect(plan.proposalCountOf(plan.steps[1]), 1, reason: 'théorie [S]');
    // Jeu [S] : minutes + variante ludique + lien (pas d'adaptation).
    expect(plan.proposalCountOf(plan.steps[6]), 3);
    expect(plan.proposalCountOf(plan.steps[7]), 1, reason: 'bilan');
  });

  test('counts the game adaptation of the audience only', () {
    final base = _plan();
    final game = base.sheet.game;
    RunPlan withAdaptation(Audience audience) => base.copyWith(
      audience: audience,
      sheet: base.sheet.copyWith(
        game: game.copyWith(
          adaptation: const SheetAdaptation(children: 'plus simple'),
        ),
      ),
    );

    expect(
      withAdaptation(Audience.children).proposalCountOf(base.steps[6]),
      4,
      reason: 'minutes + variante + lien + adaptation enfants',
    );
    expect(
      withAdaptation(Audience.adults).proposalCountOf(base.steps[6]),
      3,
      reason: 'adaptation enfants ignorée pour des adultes',
    );
  });

  group('proposal count of the game step', () {
    // Le lien avec la séance précédente est obligatoire dès qu'il y en a une
    // (invariant de SessionSheet) : il compte toujours pour 1.
    RunPlan withGame({
      Provenance src = Provenance.s,
      Audience audience = Audience.children,
      SheetAdaptation adaptation = const SheetAdaptation(),
    }) {
      final base = _plan();
      return base.copyWith(
        audience: audience,
        sheet: base.sheet.copyWith(
          game: sheetGame(
            src: src,
            link: _link,
          ).copyWith(adaptation: adaptation),
        ),
      );
    }

    test(
      'is the minutes, the playful variant and the link for a sourced game',
      () {
        final plan = withGame();

        expect(plan.proposalCountOf(plan.steps[6]), 3);
      },
    );

    test('adds the source when the game itself is a proposal', () {
      final plan = withGame(src: Provenance.prop);

      expect(plan.proposalCountOf(plan.steps[6]), 4);
    });

    test('adds the adaptation for adults to an adult audience', () {
      final plan = withGame(
        audience: Audience.adults,
        adaptation: const SheetAdaptation(adults: 'plus fin'),
      );

      expect(plan.proposalCountOf(plan.steps[6]), 4);
    });

    test('ignores an adaptation written for the other audience', () {
      final plan = withGame(
        adaptation: const SheetAdaptation(adults: 'plus fin'),
      );

      expect(plan.proposalCountOf(plan.steps[6]), 3);
    });

    test('adds everything: source, link and adaptation', () {
      final plan = withGame(
        src: Provenance.prop,
        adaptation: const SheetAdaptation(children: 'plus simple'),
      );

      expect(plan.proposalCountOf(plan.steps[6]), 5);
    });
  });

  group('proposal count of the recall exercise step', () {
    const recallStep = RunStep(
      kind: RunStepKind.recallExercise,
      phase: SessionPhase.welcome,
      minutes: 10,
    );

    RunPlan withRecall(Provenance? src) {
      final base = _plan();
      return base.copyWith(
        recallExercise: src == null
            ? null
            : RecallExercise(
                origin: base.previous!,
                exercise: sheetExercise(
                  'r1',
                  3,
                  block: 'bille-pleine',
                  src: src,
                ),
                pending: 2,
                students: 3,
              ),
      );
    }

    test('is the minutes and the hook for a sourced exercise', () {
      expect(withRecall(Provenance.s).proposalCountOf(recallStep), 2);
    });

    test('adds the source of a proposed exercise', () {
      expect(withRecall(Provenance.prop).proposalCountOf(recallStep), 3);
    });

    test('has no exercise to count without a recall exercise', () {
      expect(withRecall(null).proposalCountOf(recallStep), 2);
    });
  });

  test('has no first step for a phase without step', () {
    final plan = _plan().copyWith(steps: const []);

    expect(plan.firstStepOf(SessionPhase.game), isNull);
  });

  test('finds the element of a step', () {
    final plan = _plan();

    expect(plan.theoryOf(plan.steps[1])?.id, 't1');
    expect(plan.initiationOf(plan.steps[3])?.id, 'i1');
    expect(plan.exerciseOf(plan.steps[5])?.id, 'e2');
    expect(plan.exerciseOf(plan.steps[0]), isNull);
  });

  test('ranks the exercises among the shown ones', () {
    final plan = _plan();

    expect(plan.exerciseCount, 2);
    expect(plan.exerciseIndexOf(plan.steps[4]), 1);
    expect(plan.exerciseIndexOf(plan.steps[5]), 2);
    expect(plan.exerciseIndexOf(plan.steps[0]), isNull);
  });

  test('lists the illustrations of each kind of step', () {
    final plan = _plan();

    expect(plan.illustrationsOf(plan.steps[1]).map((i) => i.id), ['contact']);
    expect(plan.illustrationsOf(plan.steps[2]), isEmpty);
    expect(plan.illustrationsOf(plan.steps[3]).map((i) => i.id), ['schema']);
    expect(plan.illustrationsOf(plan.steps[4]), isEmpty);
    expect(plan.illustrationsOf(plan.steps[6]).map((i) => i.id), ['jeu']);
    expect(plan.illustrationsOf(plan.steps[7]), isEmpty);
  });

  test('reuses the illustration of the previous session in the recall', () {
    final plan = _plan();
    final withReuse = plan.copyWith(
      sheet: plan.sheet.copyWith(
        recall: plan.sheet.recall.copyWith(
          reuse: SheetReuse(
            sheet: SheetId('bille-pleine-2'),
            illustration: 'contact-plein',
          ),
        ),
      ),
    );

    expect(withReuse.illustrationsOf(withReuse.steps[0]).map((i) => i.id), [
      'contact-plein',
    ]);
    expect(plan.illustrationsOf(plan.steps[0]), isEmpty);
  });

  test('knows which steps can be shown to the students', () {
    final plan = _plan(diagrams: {'entrainement-p05-e1': _diagram('x')});

    expect(plan.isPresentable(plan.steps[1]), isTrue);
    expect(plan.isPresentable(plan.steps[2]), isFalse);
    expect(plan.isPresentable(plan.steps[4]), isTrue);
    expect(plan.isPresentable(plan.steps[5]), isFalse);
    expect(plan.isPresentable(plan.steps[7]), isFalse);
  });

  test('a step with only a PDF reference has nothing to show', () {
    final plan = _plan();
    const pdf = Illustration.pdfRef(
      id: 'fiche',
      caption: 'Fiche.',
      alt: 'Renvoi à la page 6.',
      file: 'Fiches.pdf',
      page: 6,
    );
    final withPdf = plan.copyWith(
      sheet: plan.sheet.copyWith(
        illustrations: [...plan.sheet.illustrations, pdf],
        theorySections: [
          theorySection('t1', illustrations: ['contact', 'fiche']),
          theorySection('t2', illustrations: ['fiche']),
        ],
      ),
    );

    // t2 n'a que le renvoi : lisible dans le guide, rien à montrer.
    expect(withPdf.illustrationsOf(withPdf.steps[2]), [pdf]);
    expect(withPdf.isPresentable(withPdf.steps[2]), isFalse);
    expect(withPdf.presentableIllustrationsOf(withPdf.steps[2]), isEmpty);
    // t1 garde son illustration dessinée, sans le renvoi.
    expect(withPdf.isPresentable(withPdf.steps[1]), isTrue);
    expect(withPdf.presentableIllustrationsOf(withPdf.steps[1]), hasLength(1));
  });

  test('marks the proposals of each kind of step', () {
    final plan = _plan(recall: Provenance.prop, exercise: Provenance.prop);

    expect(plan.isProposal(plan.steps[0]), isTrue);
    expect(plan.isProposal(plan.steps[1]), isFalse);
    expect(plan.isProposal(plan.steps[3]), isFalse);
    expect(plan.isProposal(plan.steps[4]), isTrue);
    expect(plan.isProposal(plan.steps[5]), isFalse);
    expect(plan.isProposal(plan.steps[6]), isFalse);
    expect(plan.isProposal(plan.steps[7]), isFalse);
  });

  test('marks an adapted game as a proposal', () {
    final plan = _plan();
    final adapted = plan.copyWith(
      sheet: plan.sheet.copyWith(
        game: sheetGame(adapted: true, src: Provenance.prop, link: _link),
      ),
    );

    expect(adapted.isProposal(adapted.steps[6]), isTrue);
  });

  test('shows nothing for a diagram reference without illustration', () {
    final plan = _plan();

    expect(plan.illustration('absente'), isNull);
    expect(plan.illustration('jeu'), isA<Illustration>());
  });
}
