import 'package:billard_cfa/entities/exercise_diagram/data/diagram_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:flutter_test/flutter_test.dart';

const _page = '''
version: 1
source: {file: "Fiches Test.pdf", page: 3, rank: S}
diagrams:
  - id: test-p03-e2
    kind: exercise
    sheet: "La quantité de bille pleine"
    exercise: 2
    caption: "Empocher six billes."
    success_rate: [4, 6]
    bridge: surface
    bronze: true
    table: {view: top, head_end: left}
    balls:
      - {id: y1, color: yellow, at: [1.4, 1.5], label: "x4", order: 1}
      - {id: w, color: white, at: [3, 3], role: cue}
    ghosts:
      - {id: g1, at: [1.2, 1.4], role: impact, for: w, label: 1}
    arrows:
      - {id: a1, ball: y1, kind: object, path: [[1.4, 1.5], [0, 0]], to: tl, note: "lu"}
      - {id: a2, ball: w, kind: cue, path: [[3, 3], [4, 4], [1.2, 1.4]], bounces: [bottom]}
    zones:
      - {id: z1, shape: rect, from: [0, 0], to: [2, 4], label: "zone grise"}
    sequence:
      - {step: 1, cue: w, hit: y1, contact: three_quarter, pocket: tl, repeat: 4, from: g1}
      - {step: 2, cue: w, hit: y1, contact: none, from: w, effect: "rétro"}
    inset: {contact: full, tip_point: center}
    annotations: ["x 4"]
    description: "Texte libre."
    uncertainties: ["ligne de départ"]
  - id: test-p03-photo
    kind: technique-photo
    caption: "Photo."
    description: "Photo."
    uncertainties: []
''';

String _page1(String body) => '''
version: 1
source: {file: "Test.pdf", page: 1, rank: S}
diagrams:
  - id: bad
    kind: exercise
    sheet: "Fiche"
    caption: "Légende."
    description: "Texte."
    uncertainties: []
$body''';

const _valid = '''
    balls:
      - {id: w, color: white, at: [1, 1], role: cue}
''';

void expectInvalid(String source, List<String> fragments) {
  expect(
    () => parseDiagramPage(source),
    throwsA(
      isA<InvalidDiagramPage>().having(
        (e) => e.message,
        'message',
        allOf([for (final fragment in fragments) contains(fragment)]),
      ),
    ),
  );
}

void main() {
  final parsed = parseDiagramPage(_page);

  group('identity', () {
    test('keeps table diagrams only', () {
      expect(parsed.map((d) => d.id), ['test-p03-e2']);
    });

    test('reads the sheet, exercise and source', () {
      final d = parsed.single;

      expect(d.kind, DiagramKind.exercise);
      expect(d.sheet, 'La quantité de bille pleine');
      expect(d.exercise, 2);
      expect(d.sourceFile, 'Fiches Test.pdf');
      expect(d.sourcePage, 3);
      expect(d.key.exercise, 2);
    });

    test('reads rate, bridge, bronze and text fields', () {
      final d = parsed.single;

      expect(d.successRate!.successes, 4);
      expect(d.successRate!.attempts, 6);
      expect(d.bridge, DiagramBridge.surface);
      expect(d.bronze, isTrue);
      expect(d.caption, 'Empocher six billes.');
      expect(d.description, 'Texte libre.');
      expect(d.annotations, ['x 4']);
      expect(d.uncertainties, ['ligne de départ']);
    });

    test('defaults optional fields', () {
      final d = parseDiagramPage(_page1(_valid)).single;

      expect(d.exercise, isNull);
      expect(d.successRate, isNull);
      expect(d.bridge, isNull);
      expect(d.bronze, isFalse);
      expect(d.annotations, isEmpty);
      expect(d.table.steps, isEmpty);
    });

    test('reads the game and initiation kinds', () {
      final game = _page1(_valid).replaceFirst('kind: exercise', 'kind: game');
      final initiation = _page1(_valid)
          .replaceFirst('kind: exercise', 'kind: initiation');

      expect(parseDiagramPage(game).single.kind, DiagramKind.game);
      expect(parseDiagramPage(initiation).single.kind, DiagramKind.initiation);
    });

    test('an empty page gives no diagram', () {
      const empty = '''
version: 1
source: {file: "T.pdf", page: 1, rank: S}
no_illustration: true
diagrams: []
''';

      expect(parseDiagramPage(empty), isEmpty);
    });
  });

  group('table', () {
    final table = parsed.single.table;

    test('reads balls', () {
      expect(table.balls, [
        const TableBall(
          id: 'y1',
          color: TableBallColor.yellow,
          at: TablePoint(1.4, 1.5),
          label: 'x4',
          order: 1,
        ),
        const TableBall(
          id: 'w',
          color: TableBallColor.white,
          at: TablePoint(3, 3),
          role: TableBallRole.cue,
        ),
      ]);
    });

    test('reads ghosts with a numeric label as text', () {
      expect(table.ghosts, [
        const TableGhost(
          id: 'g1',
          at: TablePoint(1.2, 1.4),
          role: TableGhostRole.impact,
          forBallId: 'w',
          label: '1',
        ),
      ]);
    });

    test('reads arrows with pocket, bounces and note', () {
      expect(table.arrows, [
        const TableArrow(
          id: 'a1',
          kind: TableArrowKind.object,
          path: [TablePoint(1.4, 1.5), TablePoint(0, 0)],
          ballId: 'y1',
          pocket: TablePocket.tl,
          note: 'lu',
        ),
        const TableArrow(
          id: 'a2',
          kind: TableArrowKind.cue,
          path: [TablePoint(3, 3), TablePoint(4, 4), TablePoint(1.2, 1.4)],
          ballId: 'w',
          bounces: [TableBand.bottom],
        ),
      ]);
    });

    test('reads rectangular zones', () {
      expect(table.zones, [
        const TableZone(
          id: 'z1',
          from: TablePoint(0, 0),
          to: TablePoint(2, 4),
          label: 'zone grise',
        ),
      ]);
    });

    test('reads steps, with "none" contact and own start as defaults', () {
      expect(table.steps, [
        const TableStep(
          cueId: 'w',
          hitId: 'y1',
          contact: TableContact.threeQuarter,
          pocket: TablePocket.tl,
          repeat: 4,
          fromGhostId: 'g1',
        ),
        const TableStep(cueId: 'w', hitId: 'y1', extras: {'effect': 'rétro'}),
      ]);
    });
  });

  group('refuses what the model cannot represent', () {
    test('invalid YAML', () {
      expectInvalid('a: [', ['YAML invalide']);
    });

    test('a root that is not an object', () {
      expectInvalid('- 1', ['racine']);
    });

    test('a missing source', () {
      expectInvalid('diagrams: []', ['source']);
    });

    test('a missing diagram list', () {
      expectInvalid('source: {file: "T.pdf", page: 1}', ['diagrams']);
    });

    test('a diagram that is not an object', () {
      expectInvalid('source: {file: "T.pdf", page: 1}\ndiagrams: [3]', [
        'diagrams',
        '3',
      ]);
    });

    test('an unknown ball color, naming the diagram and the field', () {
      final source = _page1('''
    balls:
      - {id: y, color: pink, at: [1, 1]}
''');

      expectInvalid(source, ['[bad]', 'balls[0].color', 'pink']);
    });

    test('a ball field the model does not carry', () {
      final source = _page1('''
    balls:
      - {id: y, color: red, at: [1, 1], spin: left}
''');

      expectInvalid(source, ['balls[0]', 'spin']);
    });

    test('a point that is not two numbers', () {
      final source = _page1('''
    balls:
      - {id: y, color: red, at: [1]}
''');

      expectInvalid(source, ['balls[0].at']);
    });

    test('an arrow path that is not a list', () {
      final source = _page1('''
    balls:
      - {id: w, color: white, at: [1, 1]}
    arrows:
      - {id: a, kind: cue, path: 3}
''');

      expectInvalid(source, ['arrows[0].path']);
    });

    test('an unknown band', () {
      final source = _page1('''
    balls:
      - {id: w, color: white, at: [1, 1]}
    arrows:
      - {id: a, kind: cue, path: [[1, 1], [2, 2]], bounces: [middle]}
''');

      expectInvalid(source, ['arrows[0].bounces', 'middle']);
    });

    test('bounces that are not a list', () {
      final source = _page1('''
    balls:
      - {id: w, color: white, at: [1, 1]}
    arrows:
      - {id: a, kind: cue, path: [[1, 1], [2, 2]], bounces: top}
''');

      expectInvalid(source, ['arrows[0].bounces']);
    });

    test('a polygon zone', () {
      final source = _page1('''
    balls:
      - {id: w, color: white, at: [1, 1]}
    zones:
      - {id: z, shape: polygon, from: [0, 0], to: [1, 1]}
''');

      expectInvalid(source, ['zones[0].shape', 'polygon']);
    });

    test('a step number out of order', () {
      final source = _page1('''
    balls:
      - {id: w, color: white, at: [1, 1]}
    sequence:
      - {step: 2, cue: w}
''');

      expectInvalid(source, ['sequence[0].step', '2 au lieu de 1']);
    });

    test('a table kind without balls', () {
      expectInvalid(_page1(''), ['balls']);
    });

    test('a list of objects holding something else', () {
      final source = _page1('''
    balls:
      - 3
''');

      expectInvalid(source, ['balls', '3']);
    });

    test('a field that must be a list', () {
      final source = _page1('''
    balls:
      - {id: w, color: white, at: [1, 1]}
    zones: 4
''');

      expectInvalid(source, ['zones', 'liste']);
    });

    test('annotations that are not a list', () {
      final source = _page1('''
    balls:
      - {id: w, color: white, at: [1, 1]}
    annotations: text
''');

      expectInvalid(source, ['annotations']);
    });

    test('a blank sheet', () {
      final source = _page1(_valid)
          .replaceFirst('sheet: "Fiche"', 'sheet: " "');

      expectInvalid(source, ['sheet']);
    });

    test('a success rate that is not two integers', () {
      final source = _page1(_valid).replaceFirst(
        'uncertainties: []',
        'uncertainties: []\n    success_rate: [5]',
      );

      expectInvalid(source, ['success_rate']);
    });

    test('a success rate out of bounds', () {
      final source = _page1(_valid).replaceFirst(
        'uncertainties: []',
        'uncertainties: []\n    success_rate: [9, 6]',
      );

      expectInvalid(source, ['[bad]', 'hors bornes']);
    });

    test('a bronze flag that is not a boolean', () {
      final source = _page1(
        _valid,
      ).replaceFirst('uncertainties: []', 'uncertainties: []\n    bronze: oui');

      expectInvalid(source, ['bronze']);
    });

    test('an exercise number that is not an integer', () {
      final source = _page1(_valid).replaceFirst(
        'uncertainties: []',
        'uncertainties: []\n    exercise: premier',
      );

      expectInvalid(source, ['exercise']);
    });
  });

  test('names the page error in its text', () {
    expect(
      const InvalidDiagramPage('p03 : bronze').toString(),
      'InvalidDiagramPage(p03 : bronze)',
    );
  });

  group('inset', () {
    test('reads the ball quantity and the tip point', () {
      expect(
        parsed.single.table.inset,
        const TableInset(contact: TableContact.full),
      );
    });

    test('maps the transcribed tip point to the nearest of the nine', () {
      final page = parseDiagramPage(
        _page1('''
    balls:
      - {id: w, color: white, at: [1, 1], role: cue}
    inset: {contact: half, tip_point: lower_center, bridge_height: surface}
'''),
      );

      expect(
        page.single.table.inset,
        const TableInset(contact: TableContact.half, tipPoint: TipPoint.bottom),
      );
    });

    test('is absent when the sheet draws no ball quantity', () {
      final page = parseDiagramPage(
        _page1('''
    balls:
      - {id: w, color: white, at: [1, 1], role: cue}
    inset: {contact: none, tip_point: center}
'''),
      );

      expect(page.single.table.inset, isNull);
    });

    test('refuses a tip point it does not know', () {
      expectInvalid(
        _page1('''
    balls:
      - {id: w, color: white, at: [1, 1], role: cue}
    inset: {contact: half, tip_point: sideways}
'''),
        ['inset.tip_point', 'sideways'],
      );
    });
  });
}
