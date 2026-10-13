// Données de référence lues dans le dépôt : catalogue, diagrammes,
// initiation.md, jeux.md, docs/sources.
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../diagrammes/model.dart';
import 'catalogue.dart';

/// Un diagramme transcrit (FORMAT des diagrammes).
class DiagramInfo {
  const DiagramInfo({
    required this.id,
    required this.kind,
    required this.sheet,
    required this.exercise,
    required this.rank,
    required this.folder,
  });

  final String id;
  final String kind;
  final String? sheet;
  final int? exercise;

  /// `S` ou `Prop` (rang du fichier).
  final String rank;

  /// Dossier de `diagrammes/` (`entrainement`, `proposition`...).
  final String folder;
}

/// Tout ce que les règles de validation lisent hors de la séance.
class FichesContext {
  FichesContext({
    required this.structure,
    required this.diagrams,
    required this.initiationSheets,
    required this.games,
    required this.sourceFiles,
  });

  /// Lit les références à partir de la racine du dépôt [root].
  factory FichesContext.load(String root) {
    final knowledge = '$root/docs/knowledge';
    final blocks = parseCatalogue(
      File('$knowledge/03-exercices/catalogue-entrainement.yaml')
          .readAsStringSync(),
    );
    return FichesContext(
      structure: computeStructure(blocks),
      diagrams: _loadDiagrams('$knowledge/03-exercices/diagrammes'),
      initiationSheets: _tableNumbers(
        File('$knowledge/03-exercices/initiation.md'),
      ),
      games: _tableNumbers(File('$knowledge/03-exercices/jeux.md')),
      sourceFiles: _listNames(Directory('$root/docs/sources')),
    );
  }

  final Structure structure;
  final Map<String, DiagramInfo> diagrams;
  final Set<int> initiationSheets;
  final Set<int> games;
  final Set<String> sourceFiles;
}

Map<String, DiagramInfo> _loadDiagrams(String dir) {
  final result = <String, DiagramInfo>{};
  final base = Directory(dir);
  if (!base.existsSync()) return result;
  for (final folder in base.listSync().whereType<Directory>()) {
    final name = folder.path.split(Platform.pathSeparator).last;
    for (final file in folder.listSync().whereType<File>()) {
      if (!file.path.endsWith('.yaml')) continue;
      final Object? doc;
      try {
        doc = toPlain(loadYaml(file.readAsStringSync()));
      } on YamlException {
        continue;
      }
      if (doc is! Map<String, Object?>) continue;
      final source = doc['source'];
      final rank = source is Map && source['rank'] == 'Prop' ? 'Prop' : 'S';
      for (final d in mapsOf(doc, 'diagrams')) {
        final id = d['id'];
        if (id is! String) continue;
        final exercise = d['exercise'];
        result[id] = DiagramInfo(
          id: id,
          kind: '${d['kind']}',
          sheet: d['sheet'] is String ? d['sheet']! as String : null,
          exercise: exercise is int ? exercise : null,
          rank: rank,
          folder: name,
        );
      }
    }
  }
  return result;
}

/// Numéros de la première colonne du premier tableau Markdown du fichier.
Set<int> _tableNumbers(File file) {
  final numbers = <int>{};
  if (!file.existsSync()) return numbers;
  var inTable = false;
  for (final line in file.readAsLinesSync()) {
    final isRow = line.trimLeft().startsWith('|');
    if (!isRow) {
      if (inTable) break;
      continue;
    }
    inTable = true;
    final cells = line.split('|');
    if (cells.length < 3) continue;
    final n = int.tryParse(cells[1].trim());
    if (n != null) numbers.add(n);
  }
  return numbers;
}

Set<String> _listNames(Directory dir) {
  if (!dir.existsSync()) return {};
  return {
    for (final f in dir.listSync().whereType<File>())
      f.path.split(Platform.pathSeparator).last,
  };
}
