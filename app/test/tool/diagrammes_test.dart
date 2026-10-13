import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/diagrammes/ascii_renderer.dart';
import '../../tool/diagrammes/cli.dart';
import '../../tool/diagrammes/summary.dart';
import '../../tool/diagrammes/validator.dart';

/// Exemple repris tel quel du FORMAT.md (section 2).
const formatExample = '''
version: 1
source: {file: "Fiches Entrainement CFA blackball.pdf", page: 3, rank: S}
diagrams:
  - id: entrainement-p03-e1
    kind: exercise
    sheet: "La quantité de bille pleine"
    exercise: 1
    caption: "Empocher huit billes en quantité de bille pleine, avec un chevalet sur cadre."
    success_rate: [6, 8]
    bridge: frame
    bronze: true
    table: {view: top, head_end: left}
    balls:
      - {id: y1, color: yellow, at: [1.4, 1.5], label: "x4"}
      - {id: w,  color: white,  at: [2.9, 3.0], role: cue}
    ghosts:
      - {id: g1, at: [1.2, 1.4], role: impact, for: w}
      - {id: g2, at: [2.9, 3.0], role: cue_start, label: "1"}
    arrows:
      - {id: a1, ball: y1, kind: object, path: [[1.4, 1.5], [0, 0]], to: tl}
      - {id: a2, ball: w,  kind: cue, path: [[2.9, 3.0], [1.2, 1.4]], bounces: []}
    zones:
      - {id: z1, shape: rect, from: [0, 0], to: [2, 4], label: "zone grise"}
    sequence:
      - {step: 1, cue: w, hit: y1, contact: full, pocket: tl, repeat: 4}
    inset:
      contact: full
      tip_point: center
      bridge_height: surface
    annotations: ["x 4 : la même situation est répétée 4 fois"]
    description: >-
      Texte libre en français décrivant ce que montre le schéma.
    uncertainties: []
''';

/// Fichier minimal valide dont [diagram] remplace le bloc `diagrams`.
String fileWith(String diagramYaml) =>
    '''
version: 1
source: {file: "f.pdf", page: 1}
diagrams:
$diagramYaml
''';

/// Diagramme minimal valide ; [extra] est ajouté en fin de bloc.
String diagram({String id = 'd1', String extra = ''}) =>
    '''
  - id: $id
    kind: exercise
    caption: "Légende"
    description: "Description"
    uncertainties: []
    table: {view: top, head_end: left}
    balls:
      - {id: r1, color: red, at: [4.0, 2.0]}
      - {id: w, color: white, at: [3.0, 3.0]}
$extra''';

void main() {
  List<String> errorsOf(String yaml) => validateDiagramFile(yaml).errors;

  group('validation', () {
    test('accepts the FORMAT example', () {
      final report = validateDiagramFile(formatExample);
      expect(report.errors, isEmpty);
      expect(report.diagrams, hasLength(1));
    });

    test('accepts a minimal diagram', () {
      expect(errorsOf(fileWith(diagram())), isEmpty);
    });

    test('accepts an empty file flagged no_illustration', () {
      const yaml = '''
version: 1
source: {file: "f.pdf", page: 2}
no_illustration: true
diagrams: []
''';
      expect(errorsOf(yaml), isEmpty);
    });

    test('rejects empty diagrams without no_illustration', () {
      const yaml = '''
version: 1
source: {file: "f.pdf", page: 2}
diagrams: []
''';
      expect(errorsOf(yaml).single, contains('no_illustration'));
    });

    test('reports malformed YAML', () {
      expect(errorsOf('a: [1, 2').single, contains('YAML'));
    });

    test('requires version and source', () {
      final errors = errorsOf('diagrams: []\nno_illustration: true\n');
      expect(errors.join('\n'), contains('version'));
      expect(errors.join('\n'), contains('source'));
    });

    test('rejects a non positive source page', () {
      const yaml = '''
version: 1
source: {file: "f.pdf", page: 0}
no_illustration: true
diagrams: []
''';
      expect(errorsOf(yaml).single, contains('source.page'));
    });

    test('requires mandatory diagram fields', () {
      const yaml = '''
version: 1
source: {file: "f.pdf", page: 1}
diagrams:
  - kind: technique-photo
''';
      final text = errorsOf(yaml).join('\n');
      expect(text, contains('id'));
      expect(text, contains('description'));
      expect(text, contains('uncertainties'));
      expect(text, contains('caption'));
    });

    test('requires balls and table for an exercise', () {
      const yaml = '''
version: 1
source: {file: "f.pdf", page: 1}
diagrams:
  - {id: d1, kind: exercise, caption: c, description: d, uncertainties: []}
''';
      final text = errorsOf(yaml).join('\n');
      expect(text, contains('balls'));
      expect(text, contains('table'));
    });

    test('accepts a technique-photo without balls', () {
      const yaml = '''
version: 1
source: {file: "f.pdf", page: 4}
diagrams:
  - id: t1
    kind: technique-photo
    description: "Photo d'une posture"
    uncertainties: ["angle du coude"]
    subject: "Posture"
''';
      expect(errorsOf(yaml), isEmpty);
    });

    test('rejects an unknown kind, color, bridge and pocket', () {
      final yaml = fileWith(
        diagram(
              extra: '''
    bridge: nowhere
    arrows:
      - {id: a1, ball: r1, kind: object, path: [[4, 2], [0, 0]], to: zz}
''',
            )
            .replaceFirst('kind: exercise', 'kind: puzzle')
            .replaceFirst('color: red', 'color: green'),
      );
      final text = errorsOf(yaml).join('\n');
      expect(text, contains('kind'));
      expect(text, contains('color'));
      expect(text, contains('bridge'));
      expect(text, contains('to'));
    });

    test('rejects duplicate diagram ids in a file', () {
      final yaml = fileWith('${diagram()}${diagram()}');
      expect(errorsOf(yaml).join('\n'), contains('dupliqué'));
    });

    test('rejects an unknown ghost role and ghost.for reference', () {
      final yaml = fileWith(
        diagram(
          extra: '''
    ghosts:
      - {id: g1, at: [1, 1], role: weird, for: nobody}
''',
        ),
      );
      final text = errorsOf(yaml).join('\n');
      expect(text, contains('role'));
      expect(text, contains('nobody'));
    });

    test('rejects an unknown arrow kind, ball and band', () {
      final yaml = fileWith(
        diagram(
          extra: '''
    arrows:
      - {id: a1, ball: ghost, kind: dash, path: [[1, 1], [2, 2]], bounces: [middle]}
''',
        ),
      );
      final text = errorsOf(yaml).join('\n');
      expect(text, contains('kind'));
      expect(text, contains('ghost'));
      expect(text, contains('middle'));
    });

    test('rejects a short arrow path', () {
      final yaml = fileWith(
        diagram(
          extra: '''
    arrows:
      - {id: a1, ball: r1, kind: cue, path: [[1, 1]]}
''',
        ),
      );
      expect(errorsOf(yaml).join('\n'), contains('path'));
    });

    test('rejects a sequence referencing unknown balls or contact', () {
      final yaml = fileWith(
        diagram(
          extra: '''
    sequence:
      - {step: 1, cue: nope, hit: nada, contact: huge, pocket: tl}
''',
        ),
      );
      final text = errorsOf(yaml).join('\n');
      expect(text, contains('nope'));
      expect(text, contains('nada'));
      expect(text, contains('contact'));
    });

    test('rejects an invalid zone', () {
      final yaml = fileWith(
        diagram(
          extra: '''
    zones:
      - {id: z1, shape: blob}
      - {id: z2, shape: rect, from: [0, 0]}
''',
        ),
      );
      final text = errorsOf(yaml).join('\n');
      expect(text, contains('shape'));
      expect(text, contains('to'));
    });

    test('rejects coordinates outside the tolerance box', () {
      final yaml = fileWith(diagram().replaceFirst('[4.0, 2.0]', '[9.0, 2.0]'));
      expect(errorsOf(yaml).join('\n'), contains('hors de'));
    });

    test('accepts coordinates on the tolerance border', () {
      final yaml = fileWith(
        diagram().replaceFirst('[4.0, 2.0]', '[8.5, -0.5]'),
      );
      expect(errorsOf(yaml), isEmpty);
    });

    test('validates success_rate', () {
      String withRate(String rate) =>
          fileWith(diagram(extra: '    success_rate: $rate\n'));
      expect(errorsOf(withRate('[6, 8]')), isEmpty);
      expect(errorsOf(withRate('[9, 8]')).join(), contains('success_rate'));
      expect(errorsOf(withRate('[0, 8]')).join(), contains('success_rate'));
      expect(errorsOf(withRate('[3]')).join(), contains('success_rate'));
      expect(errorsOf(withRate('[1.5, 8]')).join(), contains('success_rate'));
    });

    test('rejects duplicate ball ids', () {
      final yaml = fileWith(diagram().replaceFirst('id: w,', 'id: r1,'));
      expect(errorsOf(yaml).join('\n'), contains('dupliqué'));
    });
  });

  group('warnings', () {
    test('flags a ball outside the table', () {
      final yaml = fileWith(diagram().replaceFirst('[4.0, 2.0]', '[8.3, 2.0]'));
      final report = validateDiagramFile(yaml);
      expect(report.errors, isEmpty);
      expect(report.warnings.join('\n'), contains('hors table'));
    });

    test('flags overlapping balls', () {
      final yaml = fileWith(diagram().replaceFirst('[3.0, 3.0]', '[4.1, 2.0]'));
      final report = validateDiagramFile(yaml);
      expect(report.errors, isEmpty);
      expect(report.warnings.join('\n'), contains('chevauche'));
    });

    test('has no warning on the FORMAT example', () {
      expect(validateDiagramFile(formatExample).warnings, isEmpty);
    });
  });

  group('ascii rendering', () {
    late Map<String, Object?> example;
    late List<String> lines;
    late String text;

    setUp(() {
      example = validateDiagramFile(formatExample).diagrams.single;
      text = renderAscii(example);
      lines = text.split('\n');
    });

    test('draws the table frame, pockets and start line', () {
      final grid = lines.where((l) => l.contains('O')).toList();
      expect(grid, isNotEmpty);
      expect(text, contains('|'));
      expect(text, contains('-'));
      // Six pockets.
      final head = lines.take(31).join('\n');
      expect('O'.allMatches(head).length, 6);
    });

    test('draws balls, ghosts and arrow heads', () {
      final head = lines.take(31).join('\n');
      expect(head, contains('Y'));
      expect(head, contains('W'));
      expect(head, contains('('));
      expect(head, contains(')'));
      expect(head, contains('>'));
      expect(head, contains('.'));
    });

    test('lists every element in a legend with coordinates', () {
      expect(text, contains('y1'));
      expect(text, contains('(1.4, 1.5)'));
      expect(text, contains('g1'));
      expect(text, contains('a1'));
      expect(text, contains('z1'));
      expect(text, contains(example['id']! as String));
    });

    test('writes the ghost label in parentheses', () {
      final yaml = fileWith(
        diagram(
          extra: '''
    ghosts:
      - {id: g1, at: [6.0, 1.0], role: cue_start, label: "2"}
''',
        ),
      );
      final d = validateDiagramFile(yaml).diagrams.single;
      expect(renderAscii(d).split('\n').take(31).join('\n'), contains('(2)'));
    });

    test('is deterministic', () {
      expect(renderAscii(example), text);
    });

    test('mentions warnings in the rendering', () {
      final yaml = fileWith(diagram().replaceFirst('[4.0, 2.0]', '[8.3, 2.0]'));
      final d = validateDiagramFile(yaml).diagrams.single;
      expect(renderAscii(d), contains('AVERTISSEMENT'));
    });

    test('renders a photo diagram as legend only', () {
      const yaml = '''
version: 1
source: {file: "f.pdf", page: 4}
diagrams:
  - {id: t1, kind: technique-photo, description: "Posture", uncertainties: []}
''';
      final d = validateDiagramFile(yaml).diagrams.single;
      expect(renderAscii(d), contains('technique-photo'));
    });
  });

  group('summary', () {
    test('describes the FORMAT example on one line', () {
      final d = validateDiagramFile(formatExample).diagrams.single;
      final line = summaryLine(d);
      expect(line, isNot(contains('\n')));
      expect(line, contains('entrainement-p03-e1'));
      expect(line, contains('exercise'));
      expect(line, contains('yellow=1'));
      expect(line, contains('white=1'));
      expect(line, contains('fleches=2'));
      expect(line, contains('6/8'));
      expect(line, contains('frame'));
      expect(line, contains('incertitudes=0'));
    });
  });

  group('cli', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('diagrammes_'));
    tearDown(() => dir.deleteSync(recursive: true));

    File write(String name, String content) =>
        File('${dir.path}/$name')..writeAsStringSync(content);

    test('exits 0 and prints the summary and ascii', () {
      final f = write('p03.yaml', formatExample);
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runCli(['--ascii', '--summary', f.path], out: out, err: err);
      expect(code, 0);
      expect(out.toString(), contains('entrainement-p03-e1'));
      expect(out.toString(), contains('fleches=2'));
      expect(out.toString(), contains('Y'));
    });

    test('exits 1 and reports errors', () {
      final f = write('bad.yaml', 'version: 1\n');
      final err = StringBuffer();
      final code = runCli([f.path], out: StringBuffer(), err: err);
      expect(code, 1);
      expect(err.toString(), contains('bad.yaml'));
    });

    test('exits 2 without file or with a missing file', () {
      expect(runCli([], out: StringBuffer(), err: StringBuffer()), 2);
      expect(
        runCli(['/nope/x.yaml'], out: StringBuffer(), err: StringBuffer()),
        2,
      );
    });
  });
}
