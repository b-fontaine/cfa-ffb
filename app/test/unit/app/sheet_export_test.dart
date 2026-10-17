import 'dart:math' show Point;

import 'package:billard_cfa/app/sheet_export.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_source.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_source.dart';
import 'package:billard_cfa/features/export_sheet/domain/sheet_print_input.dart';
import 'package:billard_cfa/features/run_sheet/domain/load_validated_exercises.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations_en.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations_fr.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_world.dart';
import '../../support/fixtures.dart';
import '../../support/session_sheet_fixtures.dart';

class _Diagrams implements DiagramRepository {
  _Diagrams(this._library);

  final DiagramLibrary _library;

  @override
  Future<DiagramLibrary> load() async => _library;
}

ExerciseDiagram _diagram(String id, {DiagramTable? table}) => ExerciseDiagram(
  id: id,
  kind: DiagramKind.exercise,
  sheet: 'Fiche',
  caption: 'Légende de $id',
  description: 'Description de $id',
  sourceFile: 'Test.pdf',
  sourcePage: 1,
  table:
      table ??
      const DiagramTable(
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

final _en = AppLocalizationsEn();
final _fr = AppLocalizationsFr();

void main() {
  final catalogue = buildCatalogue([
    block('posture', 1),
    block('demi-bille', 2, exercises: 4),
    block('quart-finesses', 3),
  ]);

  Future<RunPlan> plan(
    SheetId id, {
    Audience audience = Audience.children,
    List<SessionSheet>? sheets,
    List<ExerciseDiagram> diagrams = const [],
    RulesConfig? rules,
  }) async {
    final world = DomainWorld(catalogue: catalogue, config: rules);
    final resolver = ResolveRunPlan(
      FixtureSessionSheetRepository(sheets ?? catalogueFixture()),
      InMemorySessionRepository(),
      world.catalogueRepository,
      _Diagrams(DiagramLibrary(diagrams)),
      RulesStore(rules ?? RulesConfig()),
      LoadValidatedExercises(
        world.students,
        world.groups,
        world.attempts,
        world.acquisitions,
        RulesStore(world.config),
      ),
    );
    return switch (await resolver(
      id,
      audience: audience,
      withRecallExercise: false,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => fail('échec : $failure'),
    };
  }

  SheetPrintInput animator(
    RunPlan plan, {
    AppLocalizations? l10n,
    String printedOn = '12 Oct 2026',
  }) => sheetPrintInputFrom(plan, l10n ?? _en, printedOn: printedOn);

  Iterable<String> texts(SheetPrintInput input) sync* {
    for (final step in input.steps) {
      yield step.title;
      for (final block in step.blocks) {
        switch (block) {
          case SheetPrintText():
            yield '${block.label ?? ''}|${block.text}';
          case SheetPrintList():
            yield '${block.label ?? ''}|${block.items.join('|')}';
          case SheetPrintDiagram():
            yield 'diagram|${block.caption}|${block.description ?? ''}';
          case SheetPrintCaption():
            yield 'caption|${block.caption}|${block.alt}';
        }
      }
    }
  }

  group('animator sheet header', () {
    test('names the audience and the duration', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));

      expect(input.headerLines.first, 'Children, 90 min');
      expect(input.title, 'Quantité demi-bille, session 1/2');
      expect(input.shortTitle, 'Quantité demi-bille');
    });

    test('says 120 minutes for adults', () async {
      final input = animator(
        await plan(SheetId('demi-bille-1'), audience: Audience.adults),
      );

      expect(input.headerLines.first, 'Adults, 120 min');
    });

    test('gives the notion, the level and the printing date', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));

      expect(input.headerLines, contains('Notion: Viser la tangente.'));
      expect(
        input.headerLines.last,
        'Blackball, technical level 1 · printed on 12 Oct 2026 · Billard CFA',
      );
    });

    test('names the file after the sheet, audience and language', () async {
      final children = await plan(SheetId('demi-bille-1'));
      final adults = await plan(
        SheetId('demi-bille-1'),
        audience: Audience.adults,
      );

      expect(animator(children).fileName, 'session-demi-bille-1-children.pdf');
      expect(animator(adults).fileName, 'session-demi-bille-1-adults.pdf');
      expect(
        animator(children, l10n: _fr).fileName,
        'seance-demi-bille-1-enfants.pdf',
      );
      expect(animator(children, l10n: _fr).language, 'fr');
      expect(animator(children).language, 'en');
    });

    test('writes the fixed labels in the interface language', () async {
      final fr = animator(await plan(SheetId('demi-bille-1')), l10n: _fr);

      expect(fr.headerLines.first, 'Enfants, 90 min');
      expect(fr.labels.rundown, 'Déroulé');
      expect(fr.labels.total(90), 'Total : 90 min');
      expect(
        fr.labels.proposalLegend,
        '[Prop] : proposition non sourcée, à valider.',
      );
      expect(fr.labels.pageOf(2, 5), '2 / 5');
      expect(fr.labels.minutes(15), '15 min');
      expect(fr.labels.thetaWord, 'thêta');
    });
  });

  group('animator sheet steps', () {
    test(
      'follow the run plan, with its minutes, and add up to the duration',
      () async {
        final run = await plan(SheetId('demi-bille-1'));
        final input = animator(run);

        expect(input.steps, hasLength(run.steps.length));
        expect(
          [for (final s in input.steps) s.minutes],
          [for (final s in run.steps) s.minutes],
        );
        expect(input.steps.fold<int>(0, (sum, s) => sum + s.minutes), 90);
      },
    );

    test('name the phase of each step', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));

      expect(input.steps.first.phase, 'Welcome');
      expect(input.steps.last.phase, 'Review');
    });

    test('print the recall slot without naming any exercise', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));
      final slot = input.steps.singleWhere(
        (s) => s.title == 'Recall exercise: chosen during the session',
      );

      expect(slot.source, isNull);
      expect(slot.minutes, greaterThan(0));
      expect(
        (slot.blocks.single as SheetPrintText).text,
        contains('names none'),
      );
    });

    test(
      'have no recall slot step for the first session of the catalogue',
      () async {
        final input = animator(await plan(SheetId('posture-1')));

        expect(
          input.steps.where((s) => s.title.startsWith('Recall exercise')),
          isEmpty,
        );
      },
    );

    test('print an exercise with its instructions, rate and passes', () async {
      final run = await plan(SheetId('demi-bille-1'));
      final input = animator(run);
      final exercise = input.steps.firstWhere(
        (s) => s.title == 'Exercise 1 · Exercice e1',
      );
      final byLabel = {
        for (final b in exercise.blocks)
          if (b is SheetPrintText && b.label != null) b.label!: b,
      };

      expect(byLabel['Setup']!.text, 'Mise en place.');
      expect(byLabel['Instruction']!.text, 'Consigne.');
      expect(byLabel['Expected']!.text, 'Attendu.');
      expect(byLabel['Success rate']!.text, '3 out of 5');
      expect(byLabel['Passes']!.text, '1 pass per student');
      expect(exercise.source, Provenance.s);
    });

    test(
      'mark the hook and the challenge of an exercise as proposals',
      () async {
        final input = animator(await plan(SheetId('demi-bille-1')));
        final exercise = input.steps.firstWhere(
          (s) => s.title == 'Exercise 1 · Exercice e1',
        );
        final byLabel = {
          for (final b in exercise.blocks)
            if (b is SheetPrintText && b.label != null) b.label!: b,
        };

        expect(byLabel['Hook']!.proposal, isTrue);
        expect(byLabel['Hook']!.text, 'Accroche.');
        expect(byLabel['Challenge']!.proposal, isTrue);
        expect(byLabel['Setup']!.proposal, isFalse);
      },
    );

    test('carry the provenance of a proposed exercise', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              exercises: [
                sheetExercise('e1', 1, src: Provenance.prop),
                sheetExercise('e2', 2),
              ],
            )
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );

      expect(
        input.steps
            .firstWhere((s) => s.title == 'Exercise 1 · Exercice e1')
            .source,
        Provenance.prop,
      );
      expect(
        input.steps
            .firstWhere((s) => s.title == 'Exercise 2 · Exercice e2')
            .source,
        Provenance.s,
      );
    });

    test('list the frequent mistakes with their fix', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              exercises: [
                sheetExercise('e1', 1).copyWith(
                  mistakes: const [
                    SheetMistake(symptom: 'Trop fort', fix: 'Moins de vitesse'),
                  ],
                ),
                sheetExercise('e2', 2),
              ],
            )
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );
      final exercise = input.steps.firstWhere(
        (s) => s.title == 'Exercise 1 · Exercice e1',
      );
      final mistakes = exercise.blocks.whereType<SheetPrintList>().single;

      expect(mistakes.label, 'Frequent mistakes');
      expect(mistakes.items, ['Trop fort — Moins de vitesse']);
    });

    test('draw the diagram of an exercise when it is known', () async {
      final input = animator(
        await plan(
          SheetId('demi-bille-1'),
          diagrams: [_diagram('entrainement-p05-e1')],
        ),
      );
      final exercise = input.steps.firstWhere(
        (s) => s.title == 'Exercise 1 · Exercice e1',
      );
      final diagram = exercise.blocks.whereType<SheetPrintDiagram>().single;

      expect(diagram.table.balls, hasLength(1));
      expect(diagram.caption, 'Légende de entrainement-p05-e1');
      expect(diagram.description, 'Description de entrainement-p05-e1');
    });

    test('print no diagram when the diagrams cannot be read', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));

      expect(
        input.steps.expand((s) => s.blocks).whereType<SheetPrintDiagram>(),
        isEmpty,
      );
    });

    test('print the key point of a theory section, not its body', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));
      final theory = input.steps.firstWhere((s) => s.title == 'Section t1');
      final all = theory.blocks
          .whereType<SheetPrintText>()
          .map((b) => '${b.label}|${b.text}')
          .toList();

      expect(all, contains('Key point|À retenir.'));
      expect(all.join(), isNot(contains('Une phrase.')));
    });

    test('print a non table illustration as caption and alt text', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              illustrations: [contactIllustration('i1')],
              theorySections: [
                theorySection('t1', illustrations: ['i1']),
              ],
            )
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );
      final theory = input.steps.firstWhere((s) => s.title == 'Section t1');
      final caption = theory.blocks.whereType<SheetPrintCaption>().single;

      expect(caption.caption, 'Légende i1');
      expect(caption.alt, 'Texte alternatif i1');
    });

    test('draw a table illustration from its balls', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              illustrations: [
                const Illustration.table(
                  id: 'i1',
                  caption: 'Une table',
                  alt: 'Deux billes',
                  balls: [
                    IllustrationBall(
                      id: 'w',
                      color: IllustrationBallColor.white,
                      at: Point(1, 1),
                      role: IllustrationBallRole.cue,
                    ),
                    IllustrationBall(
                      id: 'r',
                      color: IllustrationBallColor.red,
                      at: Point(5, 3),
                    ),
                  ],
                  arrows: [
                    IllustrationArrow(
                      id: 'a',
                      kind: IllustrationArrowKind.cue,
                      path: [Point(1, 1), Point(5, 3)],
                    ),
                  ],
                ),
              ],
              theorySections: [
                theorySection('t1', illustrations: ['i1']),
              ],
            )
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );
      final theory = input.steps.firstWhere((s) => s.title == 'Section t1');
      final diagram = theory.blocks.whereType<SheetPrintDiagram>().single;

      expect(diagram.table.balls.map((b) => b.id), ['w', 'r']);
      expect(diagram.table.balls.first.color, TableBallColor.white);
      expect(diagram.table.balls.first.role, TableBallRole.cue);
      expect(diagram.table.balls.last.at, const Point(5, 3));
      expect(diagram.table.arrows.single.kind, TableArrowKind.cue);
      expect(diagram.caption, 'Une table');
      expect(diagram.description, 'Deux billes');
    });

    test('print the counting of an initiation', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              initiation: [
                sheetInitiation('i1'),
                sheetInitiation(
                  'i2',
                  scoring: const Scoring.checklist(criteria: ['Droit', 'Lent']),
                ),
              ],
            )
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );
      String scoring(String title) => input.steps
          .firstWhere((s) => s.title == title)
          .blocks
          .whereType<SheetPrintText>()
          .firstWhere((b) => b.label == 'Scoring')
          .text;

      expect(scoring('Initiation i1'), 'Count the successes out of 5 tries.');
      expect(
        scoring('Initiation i2'),
        'Tick each criterion: acquired or to rework.',
      );
      final criteria = input.steps
          .firstWhere((s) => s.title == 'Initiation i2')
          .blocks
          .whereType<SheetPrintList>()
          .single;
      expect(criteria.items, ['Droit', 'Lent']);
    });

    test('print the game with its rules, and its proposals marked', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              game:
                  sheetGame(
                    link: SheetLink(
                      notionOf: SheetId('posture-1'),
                      rule: 'Règle de lien.',
                      note: 'Note de lien.',
                    ),
                  ).copyWith(
                    adaptation: const SheetAdaptation(children: 'Plus court'),
                  ),
            )
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );
      final game = input.steps.firstWhere((s) => s.title == 'Jeu');
      final text = {
        for (final b in game.blocks)
          if (b is SheetPrintText && b.label != null) b.label!: b,
      };
      final rules = game.blocks.whereType<SheetPrintList>().single;

      expect(text['Players']!.text, 'Partie à 2');
      expect(rules.items, ['Règle.']);
      expect(text['Scoring']!.text, 'Score.');
      expect(text['End']!.text, 'Fin.');
      expect(text['Playful variant']!.proposal, isTrue);
      expect(text['Adaptation']!.text, 'Plus court');
      expect(text['Adaptation']!.proposal, isTrue);
      expect(
        text['Link to the previous session']!.text,
        'Règle de lien. — Note de lien.',
      );
      expect(text['Link to the previous session']!.proposal, isTrue);
    });

    test('leave the adaptation of the other audience out', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              game:
                  sheetGame(
                    link: SheetLink(
                      notionOf: SheetId('posture-1'),
                      rule: 'Règle.',
                      note: 'Note.',
                    ),
                  ).copyWith(
                    adaptation: const SheetAdaptation(adults: 'Plus long'),
                  ),
            )
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );

      expect(texts(input).where((t) => t.contains('Plus long')), isEmpty);
    });

    test('carry the provenance of every kind of step', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              recall: s.recall.copyWith(src: Provenance.ffb),
              theorySections: [theorySection('t1', src: Provenance.prop)],
              initiation: [sheetInitiation('i1', src: Provenance.web)],
              game: s.game.copyWith(src: Provenance.prop, adapted: true),
            )
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );
      Provenance? source(String title) =>
          input.steps.firstWhere((s) => s.title == title).source;

      expect(input.steps.first.source, Provenance.ffb);
      expect(source('Section t1'), Provenance.prop);
      expect(source('Initiation i1'), Provenance.web);
      expect(source('Jeu'), Provenance.prop);
      expect(input.steps.last.source, isNull);
    });

    test('print the review questions', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));
      final review = input.steps.last;

      expect((review.blocks.single as SheetPrintList).items, ['Question ?']);
    });

    test('print the recall of the welcome step', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));
      final welcome = input.steps.first;
      final blocks = welcome.blocks;

      expect((blocks[0] as SheetPrintList).label, 'Points to recall');
      expect((blocks[0] as SheetPrintList).items, ['Un point.', 'Un autre.']);
      expect(
        blocks.whereType<SheetPrintText>().map((b) => '${b.label}|${b.text}'),
        containsAll(['Question|Question ?', 'Expected answer|Réponse.']),
      );
    });
  });

  group('animator sheet sources', () {
    test('lists the sources with their rank, file and page', () async {
      final input = animator(await plan(SheetId('demi-bille-1')));

      expect(input.sources, [
        '[S] Fiches techniques CFA BàP.pdf, page 15 — Fiche 5',
      ]);
    });

    test('marks every source with its rank, in the exact line', () async {
      for (final (rank, mark) in [
        (Provenance.s, '[S]'),
        (Provenance.ffb, '[FFB]'),
        (Provenance.web, '[Web]'),
        (Provenance.prop, '[Prop]'),
      ]) {
        final sheets = [
          for (final s in catalogueFixture())
            if (s.id.value == 'demi-bille-1')
              s.copyWith(
                sources: [
                  SheetSourceRef(
                    rank: rank,
                    file: 'Fichier.pdf',
                    page: 3,
                    note: 'Une note',
                  ),
                ],
              )
            else
              s,
        ];

        final input = animator(
          await plan(SheetId('demi-bille-1'), sheets: sheets),
        );

        expect(input.sources, ['$mark Fichier.pdf, page 3 — Une note']);
      }
    });

    test('prints a source without page without the page', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              sources: const [
                SheetSourceRef(
                  rank: Provenance.ffb,
                  file: 'ffbillard.com',
                  note: 'Une note',
                ),
              ],
            )
          else
            s,
      ];

      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );

      expect(input.sources, ['[FFB] ffbillard.com — Une note']);
    });

    test('hands over the points to check', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(uncertainties: const ['Un doute'])
          else
            s,
      ];
      final input = animator(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );

      expect(input.uncertainties, ['Un doute']);
    });
  });

  group('results plan', () {
    ResultsPlan results(RunPlan plan, {AppLocalizations? l10n}) =>
        resultsPlanFrom(plan, l10n ?? _en);

    test(
      'has one series per training exercise shown for the audience',
      () async {
        final run = await plan(SheetId('demi-bille-1'));

        final series = results(run).series;

        expect(series, hasLength(2));
        expect(series.map((s) => s.exercise), [
          '1. Exercice e1',
          '2. Exercice e2',
        ]);
      },
    );

    test('leaves out an exercise the audience does not see', () async {
      final sheets = [
        for (final s in catalogueFixture())
          if (s.id.value == 'demi-bille-1')
            s.copyWith(
              exercises: [
                sheetExercise('e1', 1),
                sheetExercise('e2', 2, weight: AudienceWeight(adults: 2)),
              ],
            )
          else
            s,
      ];

      final children = results(
        await plan(SheetId('demi-bille-1'), sheets: sheets),
      );
      final adults = results(
        await plan(
          SheetId('demi-bille-1'),
          audience: Audience.adults,
          sheets: sheets,
        ),
      );

      expect(children.series, hasLength(1));
      expect(adults.series, hasLength(2));
    });

    test(
      'prefills the session, the notion and the technique, in French',
      () async {
        final series = results(
          await plan(SheetId('demi-bille-1')),
          l10n: _fr,
        ).series.first;

        expect(series.session, 'Quantité demi-bille (séance 1/2)');
        expect(series.notion, 'Viser la tangente.');
        expect(series.technique, 'Quantité demi-bille');
      },
    );

    test(
      'takes the denominator from the success rate of the exercise',
      () async {
        final series = results(await plan(SheetId('demi-bille-1')))
            .series
            .first;

        expect(series.attempts, 5);
      },
    );

    test(
      'leaves the denominator blank when the catalogue has no rate',
      () async {
        final sheets = [
          for (final s in catalogueFixture())
            if (s.id.value == 'demi-bille-1')
              s.copyWith(
                exercises: [sheetExercise('e1', 9), sheetExercise('e2', 2)],
              )
            else
              s,
        ];
        final series = results(
          await plan(SheetId('demi-bille-1'), sheets: sheets),
        ).series;

        expect(series.first.attempts, isNull);
        expect(series.last.attempts, 5);
      },
    );

    test('follows the passes required for the number of columns', () async {
      final six = await plan(
        SheetId('demi-bille-1'),
        rules: RulesConfig(passesRequired: 6),
      );

      expect(results(six).columns, 6);
      expect(results(await plan(SheetId('demi-bille-1'))).columns, 5);
    });

    test('writes the session line in the interface language', () async {
      final run = await plan(SheetId('demi-bille-1'));

      expect(
        results(run).series.first.session,
        startsWith('Quantité demi-bille ('),
      );
      expect(results(run).series.first.session, contains('session 1/'));
      expect(
        results(run, l10n: _fr).series.first.session,
        contains('séance 1/'),
      );
    });

    test(
      'writes the fixed labels of the grid in the interface language',
      () async {
        final run = await plan(SheetId('demi-bille-1'));

        final en = results(run).labels;
        expect(en.language, 'en');
        expect(en.name, 'Name:');
        expect(en.attempt, 'TRY');
        expect(en.attemptLegend(2), 'try 2');
        expect(en.thetaWord, 'theta');
        final fr = results(run, l10n: _fr).labels;
        expect(fr.language, 'fr');
        expect(fr.name, 'Nom :');
        expect(fr.attempt, 'ESSAI');
        expect(fr.attemptLegend(2), 'essai 2');
        expect(fr.thetaWord, 'thêta');
      },
    );

    test('names the file and the document in the interface language', () async {
      final run = await plan(SheetId('demi-bille-1'));

      expect(results(run).fileName, 'results-sheets-demi-bille-1-children.pdf');
      expect(results(run).title, 'Results sheets: Quantité demi-bille');
      expect(
        results(run, l10n: _fr).fileName,
        'fiches-resultats-demi-bille-1-enfants.pdf',
      );
    });
  });

  group('RunPlanExportSource', () {
    test(
      'resolves the plan without the recall exercise, for the audience asked',
      () async {
        final asked = <(SheetId, Audience)>[];
        final run = await plan(SheetId('demi-bille-1'));
        final source = RunPlanExportSource(
          sheetId: SheetId('demi-bille-1'),
          l10n: _en,
          printedOn: '12 Oct 2026',
          resolve: (id, audience) async {
            asked.add((id, audience));
            return Ok(run);
          },
        );

        final input = await source.animator(Audience.adults);
        final results = await source.results(Audience.children);

        expect(input, isA<Ok<SheetPrintInput>>());
        expect(results, isA<Ok<ResultsPlan>>());
        expect(asked, [
          (SheetId('demi-bille-1'), Audience.adults),
          (SheetId('demi-bille-1'), Audience.children),
        ]);
      },
    );

    test('hands the failure over, an unknown session for instance', () async {
      final source = RunPlanExportSource(
        sheetId: SheetId('inconnue-9'),
        l10n: _en,
        printedOn: '',
        resolve: (id, audience) async => Err(NotFound('sheet', id.value)),
      );

      expect(
        (await source.animator(
          Audience.children,
        ) as Err<SheetPrintInput>).failure,
        isA<NotFound>(),
      );
      expect(
        (await source.results(Audience.children) as Err<ResultsPlan>).failure,
        isA<NotFound>(),
      );
    });
  });
}
