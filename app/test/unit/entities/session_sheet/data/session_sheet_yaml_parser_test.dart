import 'dart:io';
import 'dart:math' show Point;

import 'package:billard_cfa/entities/session_sheet/data/session_sheet_yaml_parser.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/ghost_ball_geometry.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/player_figure_layout.dart';
import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:flutter_test/flutter_test.dart';

final String _pilot = File('assets/fiches/09-demi-bille-1.yaml')
    .readAsStringSync();

/// Remplace [from] par [to] dans la séance pilote (échoue si absent).
String _edit(String from, String to) {
  expect(_pilot, contains(from), reason: 'motif absent du pilote');
  return _pilot.replaceFirst(from, to);
}

void _refuses(String source, {String? mentioning}) {
  expect(
    () => parseSessionSheet(source),
    throwsA(
      isA<InvariantViolation>()
          .having((e) => e.code, 'code', InvariantCode.invalidSheet)
          .having(
            (e) => e.detail,
            'detail',
            mentioning == null ? isNotNull : contains(mentioning),
          ),
    ),
  );
}

String _withIllustration(String line) =>
    _edit('illustrations:\n', 'illustrations:\n$line\n');

void main() {
  late SessionSheet sheet;

  setUpAll(() => sheet = parseSessionSheet(_pilot));

  group('the pilot sheet', () {
    test('reads the identity', () {
      expect(sheet.id, SheetId('demi-bille-1'));
      expect(sheet.order, 9);
      expect(sheet.technique, 'demi-bille');
      expect(sheet.part, 1);
      expect(sheet.previous, SheetId('bille-pleine-2'));
      expect(sheet.catalogueBlock, 'demi-bille');
      expect(sheet.technicalSheets, [5]);
      expect(sheet.title, 'Quantité demi-bille');
      expect(sheet.theme.name, 'Le partage du gâteau');
    });

    test('reads the recall with its reused illustration', () {
      expect(sheet.recall.points, hasLength(3));
      expect(sheet.recall.ask, startsWith('En bille pleine'));
      expect(sheet.recall.reuse!.sheet, SheetId('bille-pleine-2'));
      expect(sheet.recall.reuse!.illustration, 'contact-plein');
      expect(sheet.recall.src, Provenance.s);
    });

    test('reads the theory sections with their weights by audience', () {
      final sections = sheet.theorySections;

      expect(sections.map((s) => s.id), [
        'tangente',
        'mot-tangente',
        'comparer',
        'fantome',
      ]);
      expect(sections[0].weight.of(Audience.children), 3);
      expect(sections[0].adultExtra, hasLength(1));
      expect(sections[0].demo, startsWith('Tirer sans empocher'));
      expect(sections[0].illustrationIds, [
        'contact-demi',
        'visee-demi',
        'taille-billes',
      ]);
      expect(sections[0].src, Provenance.s);
      expect(sections[1].weight.isShownFor(Audience.adults), isFalse);
      expect(sections[1].src, Provenance.prop);
      expect(sections[2].demo, isNull);
      expect(sections[3].weight.isShownFor(Audience.children), isFalse);
      expect(sections[3].weight.of(Audience.adults), 2);
    });

    test('reads the initiation and its counter', () {
      final item = sheet.initiation.single;

      expect(item.initiationSheet, 7);
      expect(item.illustrationId, 'schema-initiation');
      expect(item.scoring, const Scoring.counter(of: 2));
    });

    test('reads the four kinds of illustration of the pilot', () {
      final byId = {for (final i in sheet.illustrations) i.id: i};

      expect(
        byId['contact-demi'],
        const Illustration.contact(
          id: 'contact-demi',
          caption:
              'Demi-bille : la blanche, un peu plus petite, couvre la moitié '
              'de la bille de couleur ; le procédé vise le centre de la '
              'blanche.',
          alt:
              'Vue de dessus : la blanche, un peu plus petite que la bille '
              'de couleur, recouvre la moitié de celle-ci ; à droite, la '
              'blanche vue de face avec le point du procédé au centre.',
          fraction: ContactFraction.half,
          tipPoint: TipPoint.center,
        ),
      );
      expect(byId['taille-billes'], isA<BallSizeIllustration>());
      final aim = byId['visee-demi']! as GhostAimIllustration;
      expect(aim.cue, const Point<double>(1.84, 2.26));
      expect(
        isGhostAimConsistent(
          cue: aim.cue,
          object: aim.object,
          pocket: aim.pocket,
          fraction: aim.fraction,
        ),
        isTrue,
      );
      expect(aim.object, const Point<double>(5, 2));
      expect(aim.pocket, TablePocket.tr);
      expect(aim.fraction, ContactFraction.half);
      final strip = byId['quantites']! as ContactStripIllustration;
      expect(strip.fractions, [ContactFraction.full, ContactFraction.half]);
      expect(strip.highlight, ContactFraction.half);
      expect(
        (byId['schema-initiation']! as DiagramRefIllustration).diagramId,
        'initiation-p07-e1',
      );
      expect(
        (byId['schema-jeu']! as DiagramRefIllustration).diagramId,
        'jeux-p07-g1',
      );
    });

    test('reads the exercises with their catalogue reference', () {
      final first = sheet.exercises.first;

      expect(first.id, 'e1');
      expect(first.ref.blockId, 'demi-bille');
      expect(first.ref.number, 1);
      expect(first.diagramId, 'entrainement-p05-e1');
      expect(first.weight.of(Audience.children), 2);
      expect(first.weight.of(Audience.adults), 1);
      expect(first.passes, 2);
      expect(first.mistakes, hasLength(2));
      expect(first.mistakes.first.symptom, startsWith('La rouge part'));
      expect(first.playful.hook, startsWith('Chaque tir'));
      expect(first.src, Provenance.s);
      expect(sheet.exercises.last.ref.number, 2);
    });

    test('reads the game, its link and its adaptation', () {
      final game = sheet.game;

      expect(game.title, '8 billes dans une poche');
      expect(game.sourceGame, 7);
      expect(game.adapted, isFalse);
      expect(game.src, Provenance.s);
      expect(game.setupIllustrationId, 'schema-jeu');
      expect(game.rules, hasLength(6));
      expect(game.link!.notionOf, SheetId('bille-pleine-2'));
      expect(game.adaptation.children, startsWith('Rapprocher'));
      expect(game.adaptation.adults, startsWith('Après la partie'));
    });

    test('reads the review, the sources and the uncertainties', () {
      expect(sheet.reviewPrompts, hasLength(3));
      expect(sheet.sources, hasLength(7));
      expect(sheet.sources.first.rank, Provenance.s);
      expect(sheet.sources.first.page, 15);
      expect(sheet.uncertainties, hasLength(5));
    });
  });

  group('the table illustration', () {
    const table = '''
  - id: tir
    type: table
    caption: Un tir.
    alt: Une table avec deux billes.
    balls:
      - {id: w, color: white, at: [1, 2], role: cue}
      - {id: r, color: red, at: [5, 2], role: object, label: 3, order: 1}
    ghosts:
      - {id: g, at: [4.8, 2.1], role: impact, for: w, label: 1}
    arrows:
      - {id: a, kind: object, path: [[5, 2], [8, 0]], ball: r, to: tr, bounces: [top], note: Droit.}
    zones:
      - {id: z, shape: rect, from: [0, 0], to: [2, 2], label: Départ}
    sequence:
      - {step: 1, cue: w, hit: r, contact: half, pocket: tr, repeat: 2, effect: none}
      - {step: 2, cue: w, contact: none, from: w}
''';

    test('reads balls, ghosts, arrows, zones and the sequence', () {
      final parsed = parseSessionSheet(
        _edit('illustrations:\n', 'illustrations:\n$table'),
      );
      final shown = parsed.illustrations.firstWhere(
        (i) => i.id == 'tir',
      ) as TableIllustration;

      expect(shown.balls, hasLength(2));
      expect(shown.balls.last.color, IllustrationBallColor.red);
      expect(shown.balls.last.role, IllustrationBallRole.object);
      expect(shown.balls.last.label, '3');
      expect(shown.balls.last.order, 1);
      expect(shown.ghosts.single.role, IllustrationGhostRole.impact);
      expect(shown.ghosts.single.forBallId, 'w');
      expect(shown.arrows.single.pocket, TablePocket.tr);
      expect(shown.arrows.single.bounces, [IllustrationBand.top]);
      expect(shown.arrows.single.path.last, const Point<double>(8, 0));
      expect(shown.zones.single.to, const Point<double>(2, 2));
      expect(shown.steps.first.contact, ContactFraction.half);
      expect(shown.steps.first.repeat, 2);
      expect(shown.steps.first.extras, {'effect': 'none'});
      expect(shown.steps.last.contact, isNull);
      expect(shown.steps.last.fromGhostId, isNull);
    });

    test('refuses a step out of order', () {
      final broken = table.replaceFirst('step: 2', 'step: 5');

      _refuses(
        _edit('illustrations:\n', 'illustrations:\n$broken'),
        mentioning: 'step',
      );
    });

    test('refuses an unknown ball colour', () {
      final broken = table.replaceFirst('color: red', 'color: green');

      _refuses(
        _edit('illustrations:\n', 'illustrations:\n$broken'),
        mentioning: 'color',
      );
    });

    test('refuses a non rectangular zone', () {
      final broken = table.replaceFirst('shape: rect', 'shape: circle');

      _refuses(
        _edit('illustrations:\n', 'illustrations:\n$broken'),
        mentioning: 'shape',
      );
    });
  });

  group('the other illustration types', () {
    test('reads cue_ball_target, player_figure, power_ratio, angle and '
        'pdf_ref', () {
      final parsed = parseSessionSheet(
        _withIllustration(
          '''
  - {id: cible, type: cue_ball_target, tip_point: bottom_right, cue_height: low, compare: [center, top], caption: "Cible.", alt: "Cible sur la blanche."}
  - {id: posture, type: player_figure, view: both, focus: [feet, head], lead_eye: left, head_case: left_eye_over_cue, bridge: surface, caption: "Posture.", alt: "Joueur."}
  - {id: dosage, type: power_ratio, points: [{amplitude: short, speed: slow, label: "bille proche"}, {amplitude: long, speed: fast}], highlight: 1, distance_label: "Table entière", caption: "Puissance.", alt: "Plan."}
  - {id: bande, type: angle, kind: natural_rejection, vertex: [4, 0], rays: [[2, 2], [6, 2]], caption: "Angle.", alt: "Angle."}
  - {id: pdf, type: pdf_ref, file: "Fiches techniques CFA BàP.pdf", page: 15, caption: "Voir.", alt: "Renvoi."}''',
        ),
      );
      final byId = {for (final i in parsed.illustrations) i.id: i};

      expect(
        byId['cible'],
        const Illustration.cueBallTarget(
          id: 'cible',
          caption: 'Cible.',
          alt: 'Cible sur la blanche.',
          tipPoint: TipPoint.bottomRight,
          compare: [TipPoint.center, TipPoint.top],
          cueHeight: CueHeight.low,
        ),
      );
      expect(
        byId['posture'],
        const Illustration.playerFigure(
          id: 'posture',
          caption: 'Posture.',
          alt: 'Joueur.',
          view: PlayerView.both,
          focus: [PlayerMark.feet, PlayerMark.head],
          leadEye: LeadEye.left,
          headCase: HeadCase.leftEyeOverCue,
          bridge: CueBridge.surface,
        ),
      );
      final ratio = byId['dosage']! as PowerRatioIllustration;
      expect(ratio.points, [
        const PowerPoint(
          amplitude: AmplitudeLevel.short,
          speed: SpeedLevel.slow,
          label: 'bille proche',
        ),
        const PowerPoint(
          amplitude: AmplitudeLevel.long,
          speed: SpeedLevel.fast,
        ),
      ]);
      expect(ratio.highlight, 1);
      expect(ratio.distanceLabel, 'Table entière');
      final angle = byId['bande']! as AngleIllustration;
      expect(angle.kind, AngleKind.naturalRejection);
      expect(angle.rays, hasLength(2));
      final pdf = byId['pdf']! as PdfRefIllustration;
      expect(pdf.page, 15);
    });

    test('a contact_height takes no parameter and rejects any key', () {
      final parsed = parseSessionSheet(
        _withIllustration(
          '  - {id: h, type: contact_height, caption: "C.", alt: "A."}',
        ),
      );
      expect(
        parsed.illustrations.whereType<ContactHeightIllustration>(),
        hasLength(1),
      );
      _refuses(
        _withIllustration(
          '  - {id: h, type: contact_height, exaggeration: 10, '
          'caption: "C.", alt: "A."}',
        ),
        mentioning: 'exaggeration',
      );
    });

    test('a cue_ball_target needs only the tip point', () {
      final parsed = parseSessionSheet(
        _withIllustration(
          '  - {id: c, type: cue_ball_target, tip_point: top, '
          'caption: "C.", alt: "A."}',
        ),
      );
      final target = parsed.illustrations
          .whereType<CueBallTargetIllustration>()
          .single;

      expect(target.compare, isEmpty);
      expect(target.cueHeight, isNull);
    });

    test('a player_figure takes its defaults from the side view', () {
      final parsed = parseSessionSheet(
        _withIllustration(
          '  - {id: p, type: player_figure, view: side, '
          'caption: "C.", alt: "A."}',
        ),
      );
      final figure = parsed.illustrations
          .whereType<PlayerFigureIllustration>()
          .single;

      expect(figure.focus, PlayerMark.values);
      expect(figure.leadEye, isNull);
      expect(figure.headCase, isNull);
    });

    test('refuses the three retired types', () {
      for (final fields in [
        'type: cue_side, tip_point: top, cue_height: level',
        'type: stance_top, view: top',
        'type: power_scale, levels: 5',
      ]) {
        _refuses(
          _withIllustration('  - {id: a, $fields, caption: "C.", alt: "A."}'),
          mentioning: 'type',
        );
      }
    });

    test('refuses a head case on a side view', () {
      _refuses(
        _withIllustration(
          '  - {id: p, type: player_figure, view: side, '
          'head_case: cue_between_eyes, caption: "C.", alt: "A."}',
        ),
        mentioning: 'head_case',
      );
    });

    test('refuses an empty or unknown focus', () {
      _refuses(
        _withIllustration(
          '  - {id: p, type: player_figure, view: side, focus: [], '
          'caption: "C.", alt: "A."}',
        ),
        mentioning: 'focus',
      );
      _refuses(
        _withIllustration(
          '  - {id: p, type: player_figure, view: side, focus: [nose], '
          'caption: "C.", alt: "A."}',
        ),
        mentioning: 'focus',
      );
    });

    test('refuses a power point out of the closed lists', () {
      _refuses(
        _withIllustration(
          '  - {id: p, type: power_ratio, points: [{amplitude: huge, '
          'speed: slow}], caption: "C.", alt: "A."}',
        ),
        mentioning: 'amplitude',
      );
      _refuses(
        _withIllustration(
          '  - {id: p, type: power_ratio, points: [{amplitude: short, '
          'speed: 3}], caption: "C.", alt: "A."}',
        ),
        mentioning: 'speed',
      );
    });

    test('refuses a power_ratio highlight out of the points', () {
      _refuses(
        _withIllustration(
          '  - {id: p, type: power_ratio, points: [{amplitude: short, '
          'speed: slow}], highlight: 1, caption: "C.", alt: "A."}',
        ),
        mentioning: 'highlight',
      );
      _refuses(
        _withIllustration(
          '  - {id: p, type: power_ratio, highlight: 0, '
          'caption: "C.", alt: "A."}',
        ),
        mentioning: 'highlight',
      );
    });

    test('refuses a level key on a power_ratio', () {
      _refuses(
        _withIllustration(
          '  - {id: p, type: power_ratio, levels: 5, '
          'caption: "C.", alt: "A."}',
        ),
        mentioning: 'levels',
      );
    });

    test('reads a strip of the five fractions', () {
      final parsed = parseSessionSheet(
        _edit(
          'fractions: [full, half]',
          'fractions: [full, three_quarter, half, quarter, thin]',
        ),
      );
      final strip = parsed.illustrations
          .whereType<ContactStripIllustration>()
          .single;

      expect(strip.fractions, ContactFraction.values);
    });
  });

  group('strictness', () {
    test('refuses invalid yaml and a non-object root', () {
      _refuses('a: [');
      _refuses('- 1\n- 2');
      _refuses('');
    });

    test('refuses a version other than 1', () {
      _refuses(_edit('version: 1', 'version: 2'), mentioning: 'version');
    });

    test('refuses a missing required key', () {
      _refuses(_edit('notion: ', 'nope: '), mentioning: 'notion');
    });

    test('refuses an unknown key at the root and nested', () {
      _refuses(_edit('part: 1\n', 'part: 1\nextra: 1\n'), mentioning: 'extra');
      _refuses(
        _edit('  src: S\ntheory:', '  src: S\n  bonus: 1\ntheory:'),
        mentioning: 'bonus',
      );
    });

    test('refuses an unknown illustration type', () {
      _refuses(
        _withIllustration(
          '  - {id: x, type: hologram, caption: "c", alt: "a"}',
        ),
        mentioning: 'hologram',
      );
    });

    test('refuses a photo key on an illustration', () {
      _refuses(
        _withIllustration(
          '  - {id: x, type: pdf_ref, file: "f.pdf", page: 1, '
          'photo: "p.png", caption: "c", alt: "a"}',
        ),
        mentioning: 'photo',
      );
    });

    test('refuses an unknown fraction, tip point or pocket', () {
      _refuses(
        _edit(
          'fraction: half, tip_point: center',
          'fraction: huge, tip_point: center',
        ),
      );
      _refuses(_edit('tip_point: center', 'tip_point: nowhere'));
      _refuses(_edit('pocket: tr', 'pocket: zz'));
    });

    test('refuses a malformed exercise reference', () {
      _refuses(
        _edit(
          'ref: {block: demi-bille, n: 1}',
          'ref: {block: demi-bille, n: 0}',
        ),
      );
      _refuses(
        _edit('ref: {block: demi-bille, n: 1}', 'ref: {block: demi-bille}'),
      );
      _refuses(_edit('ref: {block: demi-bille, n: 1}', 'ref: demi-bille-1'));
    });

    test('refuses a malformed sheet identifier', () {
      _refuses(_edit('id: demi-bille-1\n', 'id: Demi-Bille-1\n'));
      _refuses(_edit('previous: bille-pleine-2', 'previous: Bille pleine'));
    });

    test('refuses an unknown source value', () {
      _refuses(_edit('  src: S\ntheory:', '  src: Wiki\ntheory:'));
    });

    test('refuses a weight for an unknown audience, or a zero weight', () {
      _refuses(
        _edit(
          'weight: {children: 3, adults: 3}\n      body',
          'weight: {seniors: 3}\n      body',
        ),
      );
      _refuses(
        _edit(
          'weight: {children: 3, adults: 3}\n      body',
          'weight: {children: 0}\n      body',
        ),
      );
    });

    test('reads a checklist scoring', () {
      final parsed = parseSessionSheet(
        _edit(
          'scoring: {mode: counter, of: 2}',
          'scoring: {mode: checklist, '
              'criteria: ["Contact en demi", "Rouge empochée"]}',
        ),
      );

      expect(
        parsed.initiation.single.scoring,
        const Scoring.checklist(
          criteria: ['Contact en demi', 'Rouge empochée'],
        ),
      );
    });

    test('reads a counter of 1 and refuses a counter below 1', () {
      final one = parseSessionSheet(
        _edit(
          'scoring: {mode: counter, of: 2}',
          'scoring: {mode: counter, of: 1}',
        ),
      );

      expect(one.initiation.single.scoring, const Scoring.counter(of: 1));
      _refuses(
        _edit(
          'scoring: {mode: counter, of: 2}',
          'scoring: {mode: counter, of: 0}',
        ),
        mentioning: 'of',
      );
    });

    test('refuses an empty checklist', () {
      _refuses(
        _edit(
          'scoring: {mode: counter, of: 2}',
          'scoring: {mode: checklist, criteria: []}',
        ),
        mentioning: 'criteria',
      );
    });

    test('refuses an unknown scoring mode', () {
      _refuses(_edit('mode: counter', 'mode: rating'));
    });

    test('refuses a source that is not allowed on an exercise or a game', () {
      _refuses(
        _edit(
          '      passes: 2\n      src: S',
          '      passes: 2\n      src: Web',
        ),
        mentioning: 'src',
      );
      _refuses(
        _edit('  src: S   # titre', '  src: FFB   # titre'),
        mentioning: 'src',
      );
    });

    test('accepts Prop as the source of an exercise and of a game', () {
      final parsed = parseSessionSheet(
        _edit(
          '      passes: 2\n      src: S',
          '      passes: 2\n      src: Prop',
        ).replaceFirst('  src: S   # titre', '  src: Prop   # titre'),
      );

      expect(parsed.exercises.first.src, Provenance.prop);
      expect(parsed.game.src, Provenance.prop);
    });

    test('refuses a text that is not a string', () {
      _refuses(_edit('title: Quantité demi-bille', 'title: [1, 2]'));
    });

    test('refuses an illustration cited but not defined', () {
      _refuses(
        _edit(
          'illustrations: [contact-demi, visee-demi, taille-billes]',
          'illustrations: [absente]',
        ),
      );
    });

    test('refuses a sheet that breaks a domain invariant', () {
      _refuses(_edit('order: 9', 'order: 1'));
    });

    test('refuses a proposal as a cited source rank', () {
      _refuses(
        _edit(
          'rank: S, file: Fiches techniques CFA BàP.pdf, page: 15',
          'rank: Prop, file: Fiches techniques CFA BàP.pdf, page: 15',
        ),
      );
    });

    group('refuses a value of the wrong type, naming its key', () {
      test('a text that must be a text or null', () {
        _refuses(
          _edit('previous: bille-pleine-2', 'previous: 5'),
          mentioning: 'previous',
        );
        _refuses(
          _edit('previous: bille-pleine-2', 'previous: [a]'),
          mentioning: 'previous',
        );
      });

      test('an integer that is not an integer', () {
        _refuses(_edit('order: 9', 'order: neuf'), mentioning: 'order');
        _refuses(_edit('order: 9', 'order: 9.5'), mentioning: 'order');
        _refuses(_edit('order: 9', 'order: true'), mentioning: 'order');
      });

      test('an optional integer that is not an integer', () {
        _refuses(
          _edit(
            'weight: {children: 3, adults: 3}\n      body',
            'weight: {children: beaucoup, adults: 3}\n      body',
          ),
          mentioning: 'children',
        );
      });

      test('an integer or null that is neither', () {
        _refuses(
          _edit('source_game: 7', 'source_game: sept'),
          mentioning: 'source_game',
        );
        _refuses(
          _edit('source_game: 7', 'source_game: [7]'),
          mentioning: 'source_game',
        );
      });

      test('a boolean that is not a boolean', () {
        _refuses(_edit('adapted: false', 'adapted: 0'), mentioning: 'adapted');
        _refuses(
          _edit('adapted: false', 'adapted: peut-être'),
          mentioning: 'adapted',
        );
      });

      test('a list that is not a list', () {
        _refuses(
          _edit('technical_sheets: [5]', 'technical_sheets: 5'),
          mentioning: 'technical_sheets',
        );
        _refuses(
          _edit('technical_sheets: [5]', 'technical_sheets: {a: 1}'),
          mentioning: 'technical_sheets',
        );
      });

      test('a list of integers holding a text', () {
        _refuses(
          _edit('technical_sheets: [5]', 'technical_sheets: [5, cinq]'),
          mentioning: 'technical_sheets[1]',
        );
      });

      test('an object that is not an object', () {
        _refuses(
          _edit('illustrations:\n', 'illustrations:\n  - juste-un-texte\n'),
          mentioning: 'illustrations[0]',
        );
        _refuses(
          _edit('sources:\n', 'sources:\n  - [1, 2]\n'),
          mentioning: 'sources[0]',
        );
      });

      test('a list of texts holding an empty text or a number', () {
        _refuses(
          _edit('  prompts:\n', '  prompts:\n    - 3\n'),
          mentioning: 'prompts[0]',
        );
        _refuses(
          _edit('  prompts:\n', '  prompts:\n    - ""\n'),
          mentioning: 'prompts[0]',
        );
      });

      test('a point that is not a numeric [x, y]', () {
        _refuses(_edit('cue: [1.84, 2.26]', 'cue: [1.84]'), mentioning: 'cue');
        _refuses(
          _edit('cue: [1.84, 2.26]', 'cue: [1.84, haut]'),
          mentioning: 'cue',
        );
        _refuses(_edit('cue: [1.84, 2.26]', 'cue: 1.84'), mentioning: 'cue');
      });

      test('an enum value outside its closed list', () {
        _refuses(_edit('pocket: tr', 'pocket: [tr]'), mentioning: 'pocket');
      });
    });

    test('annotates a domain invariant raised without detail', () {
      _refuses(
        _edit('ref: {block: demi-bille, n: 1}', 'ref: {block: " ", n: 1}'),
      );
    });
  });
}
