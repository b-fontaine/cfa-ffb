import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/diagrammes/ascii_renderer.dart';
import '../../tool/diagrammes/cli.dart';
import '../../tool/diagrammes/ghosts.dart';
import '../../tool/diagrammes/model.dart';
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

    test('accepts the S and Prop ranks of a source', () {
      for (final rank in ['S', 'Prop']) {
        final yaml =
            '''
version: 1
source: {file: "f", page: 1, rank: $rank}
no_illustration: true
diagrams: []
''';
        expect(errorsOf(yaml), isEmpty, reason: rank);
      }
    });

    test('rejects an unknown source rank', () {
      const yaml = '''
version: 1
source: {file: "f.pdf", page: 1, rank: Web}
no_illustration: true
diagrams: []
''';
      expect(errorsOf(yaml).single, contains('source.rank'));
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

    test('rejects an unknown inset tip point', () {
      final yaml = fileWith(
        diagram(
          extra: '''
    inset: {contact: half, tip_point: sideways}
''',
        ),
      );
      expect(errorsOf(yaml).join('\n'), contains('inset.tip_point'));
    });

    test('accepts the transcribed inset tip points', () {
      for (final tip in ['center', 'upper_center', 'lower', 'below_center']) {
        final yaml = fileWith(
          diagram(extra: '    inset: {contact: half, tip_point: $tip}\n'),
        );
        expect(errorsOf(yaml), isEmpty, reason: tip);
      }
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

    /// Diagramme à deux billes de [colors] aux abscisses données (même
    /// ordonnée), pour les seuils de chevauchement.
    List<String> overlapWarnings(
      String colorA,
      String colorB,
      double distance,
    ) {
      final yaml = fileWith('''
  - id: d1
    kind: exercise
    caption: "Légende"
    description: "Description"
    uncertainties: []
    table: {view: top, head_end: left}
    balls:
      - {id: a, color: $colorA, at: [4.0, 2.0]}
      - {id: b, color: $colorB, at: [${4.0 + distance}, 2.0]}
''');
      return validateDiagramFile(yaml).warnings;
    }

    test('a white and a red ball touch at r_c + r_o = 0.2136, not 0.2', () {
      // Seuil : 0,213622 - 0,01 de tolérance de transcription = 0,2036.
      expect(overlapWarnings('white', 'red', 0.2136), isEmpty);
      expect(overlapWarnings('white', 'red', 0.21), isEmpty);
      expect(
        overlapWarnings('white', 'red', 0.19).join(),
        contains('chevauchent'),
      );
    });

    test('two object balls touch at 2 r_o = 0.2197, tolerance 0.01', () {
      // Seuil : 0,219676 - 0,01 = 0,2097. Deux paires transcrites [S] sont à
      // 0,2195 : tangentes à la précision de transcription.
      expect(overlapWarnings('red', 'yellow', 0.2195), isEmpty);
      expect(overlapWarnings('red', 'yellow', 0.21), isEmpty);
      expect(
        overlapWarnings('red', 'yellow', 0.20).join(),
        contains('chevauchent'),
      );
    });

    test('the threshold depends on the colours of the pair', () {
      // À 0,205 : trop près pour deux billes de but (0,2097), mais pas pour
      // une blanche et une bille de but (0,2036).
      expect(overlapWarnings('white', 'red', 0.205), isEmpty);
      expect(overlapWarnings('red', 'red', 0.205), isNotEmpty);
    });

    test('white / red threshold 0.2036 is exact to 0.0002', () {
      expect(overlapWarnings('white', 'red', 0.2038), isEmpty);
      expect(overlapWarnings('white', 'red', 0.2034), isNotEmpty);
    });

    test('red / yellow threshold 0.2097 is exact to 0.0002', () {
      expect(overlapWarnings('red', 'yellow', 0.2099), isEmpty);
      expect(overlapWarnings('red', 'yellow', 0.2095), isNotEmpty);
    });

    test('a cue ball drawn as large as an object ball is caught by colour', () {
      // 0,2090 : au-delà du seuil blanche / bille de but (0,2036), en deçà du
      // seuil de deux billes de but (0,2097) : seul le choix du rayon par
      // couleur distingue les deux cas.
      expect(overlapWarnings('white', 'red', 0.2090), isEmpty);
      expect(overlapWarnings('red', 'red', 0.2090), isNotEmpty);
    });

    test('names the distance and the threshold in the warning', () {
      final warning = overlapWarnings('red', 'yellow', 0.18).single;

      expect(warning, contains('0.1800'));
      expect(warning, contains('0.2097'));
    });

    List<String> bandWarnings(String color, double x) {
      final yaml = fileWith('''
  - id: d1
    kind: exercise
    caption: "Légende"
    description: "Description"
    uncertainties: []
    table: {view: top, head_end: left}
    balls:
      - {id: a, color: $color, at: [$x, 2.0]}
''');
      return validateDiagramFile(yaml).warnings;
    }

    test('tolerates a ball 0.0098 case into the cushion (x = 0.10)', () {
      // r_o = 0,1098 : 0,1098 - 0,10 = 0,0098 < 0,01 (cas transcrit [S]).
      expect(bandWarnings('red', 0.10), isEmpty);
    });

    test('flags a ball that bites the cushion beyond the tolerance', () {
      expect(bandWarnings('red', 0.05).join(), contains('mord sur la bande'));
    });

    test('the smaller cue ball bites less at the same place', () {
      // À x = 0,09 : 0,1098 - 0,09 = 0,0198 (bille de but) ; 0,1038 - 0,09 =
      // 0,0138 (blanche) : les deux dépassent 0,01.
      expect(bandWarnings('red', 0.09), isNotEmpty);
      expect(bandWarnings('white', 0.095), isEmpty);
      expect(bandWarnings('red', 0.095), isNotEmpty);
    });

    test('the cushion thresholds are exact to 0.0002 per colour', () {
      // r_o - 0,01 = 0,0998 ; r_c - 0,01 = 0,0938.
      expect(bandWarnings('red', 0.1000), isEmpty);
      expect(bandWarnings('red', 0.0996), isNotEmpty);
      expect(bandWarnings('white', 0.0940), isEmpty);
      expect(bandWarnings('white', 0.0936), isNotEmpty);
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

    test(
      'puts the start line at 1.6 [FFB] (column 25), not 2.0 (column 30)',
      () {
        expect(startLineX, closeTo(1.6, 1e-12));
        expect(text, contains('départ x=1.6'));
        final grid = lines.take(31).toList();
        bool hasBarAt(int c) => grid.any((l) => l.length > c && l[c] == '|');
        expect(hasBarAt(6 + (1.6 * 12).round()), isTrue);
        expect(hasBarAt(6 + (2.0 * 12).round()), isFalse);
      },
    );

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

    test('--ghosts exits 1 on a proposition with a stale ghost circle', () {
      final f = write('prop.yaml', _proposition(ghostY: 1.4));
      final err = StringBuffer();
      final code = runCli(['--ghosts', f.path], out: StringBuffer(), err: err);
      expect(code, 1);
      expect(err.toString(), contains('cercle g1'));
    });

    test('--ghosts exits 0 on a proposition with the computed circle', () {
      final f = write('prop.yaml', _proposition(ghostY: 1.41));
      final code = runCli(
        ['--ghosts', f.path],
        out: StringBuffer(),
        err: StringBuffer(),
      );
      expect(code, 0);
    });

    test('exits 2 without file or with a missing file', () {
      expect(runCli([], out: StringBuffer(), err: StringBuffer()), 2);
      expect(
        runCli(['/nope/x.yaml'], out: StringBuffer(), err: StringBuffer()),
        2,
      );
    });
  });

  group('ghost circles of propositions', () {
    test('G = O - s u with s = r_c + r_o = 0.213622 straight to a pocket', () {
      final g = ghostCenter([4, 2], [4, 0]);

      expect(g[0], closeTo(4, 1e-9));
      expect(g[1], closeTo(2.213622, 1e-6));
    });

    test('G follows a diagonal: s / sqrt 2 = 0.15105 on each axis', () {
      final g = ghostCenter([1, 1], [0, 0]);

      expect(g[0], closeTo(1.15105, 1e-4));
      expect(g[1], closeTo(1.15105, 1e-4));
    });

    test('a ball on the pocket keeps its position', () {
      expect(ghostCenter([4, 0], [4, 0]), [4, 0]);
    });

    test('accepts a circle at the computed position (tolerance 0.01)', () {
      expect(ghostMismatches(_proposition(ghostY: 1.41)), isEmpty);
      expect(ghostMismatches(_proposition(ghostY: 1.42)), isEmpty);
    });

    test('the tolerance of 0.01 is exact to 0.0002 around 1.413622', () {
      // Écart 0,0099 accepté, écart 0,0101 refusé (ancienne erreur : 0,0136).
      expect(ghostMismatches(_proposition(ghostY: 1.4037)), isEmpty);
      expect(ghostMismatches(_proposition(ghostY: 1.4035)), hasLength(1));
    });

    test('flags the old position at two radii of 0.1 (0.2 behind)', () {
      final mismatches = ghostMismatches(_proposition(ghostY: 1.4));

      expect(mismatches, hasLength(1));
      expect(mismatches.single.ghost, 'g1');
      expect(mismatches.single.gap, closeTo(0.0136, 1e-3));
      expect(mismatches.single.expected[1], closeTo(1.4136, 1e-4));
      expect('${mismatches.single}', contains('(4.0, 1.41)'));
    });

    test(
      'ignores transcriptions of a PDF (rank S): positions are measures',
      () {
        final text = _proposition(ghostY: 1.4)
            .replaceFirst('rank: Prop', 'rank: S');

        expect(ghostMismatches(text), isEmpty);
      },
    );

    test('ignores a circle that matches no shot', () {
      expect(ghostMismatches(_proposition(ghostY: 2.8)), isEmpty);
    });
  });
}

/// Proposition : bille jaune en (4 ; 1,2) vers la poche du milieu, blanche en
/// (4 ; 3,6) ; le cercle d'impact est en (4 ; [ghostY]). Attendu : y = 1,4136.
String _proposition({required double ghostY}) =>
    '''
version: 1
source: {file: "Proposition (hors PDF)", page: 2, rank: Prop}
diagrams:
  - id: proposition-p02-e1
    kind: exercise
    caption: "Légende"
    description: "Description"
    uncertainties: []
    table: {view: top, head_end: left}
    balls:
      - {id: o2, color: yellow, at: [4.0, 1.2]}
      - {id: w, color: white, at: [4.0, 3.6], role: cue}
    ghosts:
      - {id: g1, at: [4.0, $ghostY], role: impact, for: w}
    sequence:
      - {step: 1, cue: w, hit: o2, contact: full, pocket: tm}
''';
