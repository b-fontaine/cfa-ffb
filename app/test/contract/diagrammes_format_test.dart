import 'dart:io';

import 'package:billard_cfa/entities/exercise_diagram/data/diagram_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/shared/ui/table_diagram/diagram_timeline.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/diagrammes/model.dart';
import '../../tool/diagrammes/validator.dart';

// Contrat entre le format documentaire (docs/knowledge/03-exercices/
// diagrammes/FORMAT.md) et le code de production.
//
// Pour chaque diagramme à table de chaque pNN.yaml :
//  1. le fichier passe le validateur de tool/diagrammes ;
//  2. le parseur de production (entities/exercise_diagram/data) le lit et
//     refuse tout champ que le modèle ne représente pas ;
//  3. le mapper de production (entities/exercise_diagram/presentation) le
//     convertit en TableDiagramSpec, et le spec reconverti en champs du FORMAT
//     est identique à la transcription (aucune perte) ;
//  4. la timeline se construit (billes, cercles et points valides).
//
// Seule la comparaison « sans perte » vit ici : le parseur et le mapper sont du
// code de production, testé unitairement dans test/unit/entities/
// exercise_diagram.

const _diagramsDir = '../docs/knowledge/03-exercices/diagrammes';

const _stepKeys = {'step', 'cue', 'hit', 'contact', 'pocket', 'repeat', 'from'};

/// Écart de transcription : la valeur ne peut pas être convertie sans perte.
class _Mismatch implements Exception {
  _Mismatch(this.message);
  final String message;
  @override
  String toString() => message;
}

String _snake(Enum e) =>
    e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

List<Json> _list(Json d, String key) => mapsOf(d, key);

// --- Comparaison sans perte : les deux côtés sont mis sous une forme
// canonique (valeurs par défaut explicites, nombres en double).

List<double> _pt(Object? raw) => pointOf(raw)!;

List<Object?> _canonOriginal(Json d) => [
  for (final b in _list(d, 'balls'))
    {
      'ball': b['id'],
      'color': b['color'],
      'at': _pt(b['at']),
      'role': b['role'],
      'label': b['label'] == null ? null : '${b['label']}',
      'order': b['order'],
    },
  for (final g in _list(d, 'ghosts'))
    {
      'ghost': g['id'],
      'at': _pt(g['at']),
      'role': g['role'],
      'for': g['for'],
      'label': g['label'] == null ? null : '${g['label']}',
    },
  for (final a in _list(d, 'arrows'))
    {
      'arrow': a['id'],
      'kind': a['kind'],
      'path': [for (final p in a['path']! as List) _pt(p)],
      'ball': a['ball'],
      'bounces': a['bounces'] ?? const <Object?>[],
      'to': a['to'],
      'label': a['label'] == null ? null : '${a['label']}',
      'note': a['note'] == null ? null : '${a['note']}',
    },
  for (final z in _list(d, 'zones'))
    {
      'zone': z['id'],
      'from': _pt(z['from']),
      'to': _pt(z['to']),
      'label': z['label'] == null ? null : '${z['label']}',
    },
  for (final s in _list(d, 'sequence'))
    {
      'cue': s['cue'],
      'hit': s['hit'],
      'contact': s['contact'] == 'none' ? null : s['contact'],
      'pocket': s['pocket'],
      'repeat': s['repeat'] ?? 1,
      'from': s['from'] == s['cue'] ? null : s['from'],
      'extras': {
        for (final e in s.entries)
          if (!_stepKeys.contains(e.key)) e.key: '${e.value}',
      },
    },
];

List<double> _xy(DiagramPoint p) => [p.x, p.y];

List<Object?> _canonSpec(TableDiagramSpec s) => [
  for (final b in s.balls)
    {
      'ball': b.id,
      'color': _snake(b.color),
      'at': _xy(b.at),
      'role': b.role == null ? null : _snake(b.role!),
      'label': b.label,
      'order': b.order,
    },
  for (final g in s.ghosts)
    {
      'ghost': g.id,
      'at': _xy(g.at),
      'role': _snake(g.role),
      'for': g.forBallId,
      'label': g.label,
    },
  for (final a in s.arrows)
    {
      'arrow': a.id,
      'kind': _snake(a.kind),
      'path': [for (final p in a.path) _xy(p)],
      'ball': a.ballId,
      'bounces': [for (final b in a.bounces) _snake(b)],
      'to': a.pocket == null ? null : _snake(a.pocket!),
      'label': a.label,
      'note': a.note,
    },
  for (final z in s.zones)
    {'zone': z.id, 'from': _xy(z.from), 'to': _xy(z.to), 'label': z.label},
  for (final st in s.steps)
    {
      'cue': st.cueId,
      'hit': st.hitId,
      'contact': st.contact == null ? null : _snake(st.contact!),
      'pocket': st.pocket == null ? null : _snake(st.pocket!),
      'repeat': st.repeat,
      'from': st.fromGhostId,
      'extras': st.extras,
    },
];

/// Problèmes d'un fichier, chacun préfixé par [label] et l'id du diagramme.
List<String> checkDiagramFile(String label, String text) {
  final report = validateDiagramFile(text);
  if (report.errors.isNotEmpty) {
    return [for (final e in report.errors) '$label : validateur : $e'];
  }
  final tables = [
    for (final d in report.diagrams)
      if (tableKinds.contains(d['kind'])) d,
  ];
  for (final d in report.diagrams) {
    if (tableKinds.contains(d['kind']) != (d['balls'] is List)) {
      return ['$label [${d['id']}] : kind ${d['kind']} et balls incohérents'];
    }
  }
  final List<ExerciseDiagram> parsed;
  try {
    parsed = parseDiagramPage(text);
  } on InvalidDiagramPage catch (e) {
    return ['$label : $e'];
  }
  final problems = <String>[];
  if (parsed.length != tables.length) {
    return ['$label : ${parsed.length} schémas lus pour ${tables.length}'];
  }
  for (final (i, d) in tables.indexed) {
    final id = d['id'];
    try {
      final spec = tableDiagramSpecOf(parsed[i]);
      final original = _canonOriginal(d);
      final back = _canonSpec(spec);
      if (original.toString() != back.toString()) {
        for (var n = 0; n < original.length; n++) {
          if (original[n].toString() != back[n].toString()) {
            throw _Mismatch(
              'perte à la conversion : ${original[n]} devient ${back[n]}',
            );
          }
        }
      }
      DiagramTimeline.from(spec);
    } on _Mismatch catch (e) {
      problems.add('$label [$id] : $e');
    } on InvalidDiagramException catch (e) {
      problems.add('$label [$id] : timeline : ${e.message}');
    }
  }
  return problems;
}

const _invalidColor = '''
version: 1
source: {file: "Test.pdf", page: 1, rank: S}
diagrams:
  - id: test-p01-e1
    kind: exercise
    caption: "Exercice de test."
    table: {view: top, head_end: left}
    balls:
      - {id: y1, color: pink, at: [1.4, 1.5]}
      - {id: w, color: white, at: [2.9, 3.0], role: cue}
    description: "Test."
    uncertainties: []
''';

// 92 pages transcrites des PDF [S] + 2 pages proposées [Prop] (6 diagrammes).
// Totaux exacts : ajouter ou retirer une page impose de mettre ces nombres à
// jour dans le même changement.
const _expectedFiles = 94;
const _expectedTables = 109;

void main() {
  group('contrat FORMAT -> TableDiagramSpec', () {
    test('chaque transcription se convertit sans perte', () {
      final root = Directory(_diagramsDir);
      expect(root.existsSync(), isTrue, reason: 'dossier introuvable');
      final files =
          root
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.yaml'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      // Nombre exact de transcriptions : une disparition silencieuse (dossier
      // vidé, fichier perdu) ou un ajout non déclaré fait échouer le contrat.
      expect(files.length, _expectedFiles);

      final problems = <String>[];
      var tables = 0;
      for (final file in files) {
        final text = file.readAsStringSync();
        final label = file.path.substring(root.path.length + 1);
        problems.addAll(checkDiagramFile(label, text));
        final doc = loadYaml(text);
        if (doc is YamlMap) {
          for (final d in (doc['diagrams'] as YamlList? ?? YamlList())) {
            if ((d as YamlMap)['balls'] is List) tables++;
          }
        }
      }

      expect(tables, _expectedTables);
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('le rang de chaque page correspond à son dossier', () {
      final root = Directory(_diagramsDir);
      final wrong = <String>[];
      for (final file in root.listSync(recursive: true).whereType<File>()) {
        if (!RegExp(r'p\d\d\.yaml$').hasMatch(file.path)) continue;
        final label = file.path.substring(root.path.length + 1);
        final source =
            (loadYaml(file.readAsStringSync()) as YamlMap)['source'] as YamlMap;
        final proposed = label.startsWith('proposition/');
        final expected = proposed ? 'Prop' : 'S';
        if (source['rank'] != expected) {
          wrong.add('$label : rank ${source['rank']} au lieu de $expected');
        }
        final file0 = source['file'] as String;
        if (proposed != (file0 == 'Proposition (hors PDF)')) {
          wrong.add('$label : file « $file0 » incohérent avec le dossier');
        }
      }

      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });

    test('une valeur invalide est signalée avec le fichier', () {
      final problems = checkDiagramFile('jeux/p99.yaml', _invalidColor);

      expect(problems, isNotEmpty);
      expect(problems.join('\n'), contains('jeux/p99.yaml'));
      expect(problems.join('\n'), contains('pink'));
    });
  });
}
