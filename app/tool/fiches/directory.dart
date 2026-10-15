// Contrôles sur l'ensemble du dossier du catalogue : règles par fichier,
// puis règles entre fichiers (V2 doublons, V5 union, V23 cohérence) et mode
// --complete.
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../diagrammes/model.dart';
import 'catalogue.dart';
import 'context.dart';
import 'session_rules.dart';

/// Résultat du contrôle d'un dossier.
class DirectoryReport {
  DirectoryReport({
    required this.files,
    required this.errorsByFile,
    required this.globalErrors,
  });

  /// Noms des fichiers `*.yaml` contrôlés, triés.
  final List<String> files;
  final Map<String, List<String>> errorsByFile;

  /// Erreurs qui portent sur plusieurs fichiers ou sur le dossier.
  final List<String> globalErrors;

  bool get ok =>
      globalErrors.isEmpty && errorsByFile.values.every((e) => e.isEmpty);

  /// Toutes les erreurs, préfixées par le fichier.
  List<String> get allErrors => [
    for (final e in errorsByFile.entries)
      for (final m in e.value) '${e.key}: $m',
    for (final m in globalErrors) 'catalogue: $m',
  ];
}

/// Documents de [dir] (`*.yaml`) par `id`, pour les contrôles croisés.
Map<String, Json> loadSiblings(String dir) {
  final result = <String, Json>{};
  final directory = Directory(dir);
  if (!directory.existsSync()) return result;
  for (final f in directory.listSync().whereType<File>()) {
    if (!f.path.endsWith('.yaml')) continue;
    final doc = _parse(f.readAsStringSync());
    final id = doc?['id'];
    if (doc != null && id is String) result[id] = doc;
  }
  return result;
}

Json? _parse(String text) {
  try {
    final doc = toPlain(loadYaml(text));
    return doc is Map<String, Object?> ? doc : null;
  } on YamlException {
    return null;
  }
}

/// Valide tous les `*.yaml` de [dir]. Avec [complete], exige en plus les 28
/// fichiers et la couverture de la plage d'exercices de chaque technique.
DirectoryReport validateDirectory(
  String dir,
  FichesContext context, {
  bool complete = false,
}) {
  final directory = Directory(dir);
  final names = <String>[
    if (directory.existsSync())
      for (final f in directory.listSync().whereType<File>())
        if (f.path.endsWith('.yaml')) f.path.split('/').last,
  ]..sort();
  final texts = {for (final n in names) n: File('$dir/$n').readAsStringSync()};
  final parsed = {for (final n in names) n: _parse(texts[n]!)};

  final global = <String>[];
  final byId = <String, Json>{};
  final fileOfId = <String, String>{};
  for (final n in names) {
    final doc = parsed[n];
    final id = doc?['id'];
    if (id is! String) continue;
    if (fileOfId.containsKey(id)) {
      global.add('V2 : $id : identifiant en double dans ${fileOfId[id]} et $n');
    } else {
      fileOfId[id] = n;
      byId[id] = doc!;
    }
  }

  final byFile = <String, List<String>>{
    for (final n in names)
      n: validateSession(
        texts[n]!,
        fileName: n,
        context: context,
        siblings: byId,
      ),
  };

  global
    ..addAll(_coherence(parsed, context.structure))
    ..addAll(_unionAndPresence(parsed, context.structure, names, complete));
  return DirectoryReport(
    files: names,
    errorsByFile: byFile,
    globalErrors: global,
  );
}

String _themeName(Json d) {
  final t = d['theme'];
  return t is Map ? '${t['name']}' : '';
}

String _variant(Json d) {
  final g = d['game'];
  return g is Map ? '${g['playful_variant']}' : '';
}

/// V23 : cohérence des parties d'une même technique.
List<String> _coherence(Map<String, Json?> parsed, Structure structure) {
  final errors = <String>[];
  final byTechnique = <String, List<Json>>{};
  for (final doc in parsed.values) {
    final t = doc?['technique'];
    if (doc != null && t is String) {
      byTechnique.putIfAbsent(t, () => []).add(doc);
    }
  }
  const fields = <String, Object? Function(Json)>{
    'title': _title,
    'notion': _notion,
    'theme.name': _themeName,
    'catalogue_block': _block,
    'technical_sheets': _sheets,
  };
  for (final entry in byTechnique.entries) {
    final docs = [...entry.value]..sort((a, b) => _part(a).compareTo(_part(b)));
    final first = docs.first;
    for (final other in docs.skip(1)) {
      for (final f in fields.entries) {
        if ('${f.value(first)}' != '${f.value(other)}') {
          errors.add(
            'V23 : ${entry.key} : champ ${f.key} différent entre '
            '${first['id']} et ${other['id']}',
          );
        }
      }
    }
    for (var i = 1; i < docs.length; i++) {
      final a = docs[i - 1];
      final b = docs[i];
      if (_part(b) == _part(a) + 1 && _variant(a) == _variant(b)) {
        errors.add(
          'V23 : ${entry.key} : playful_variant identique entre ${a['id']} '
          'et ${b['id']}',
        );
      }
    }
  }
  return errors;
}

int _part(Json d) => d['part'] is int ? d['part']! as int : 0;
Object? _title(Json d) => d['title'];
Object? _notion(Json d) => d['notion'];
Object? _block(Json d) => d['catalogue_block'];
Object? _sheets(Json d) => d['technical_sheets'];

/// V2 (fichiers manquants), V5 (union) et V23 (parties sans trou) en
/// mode --complete.
List<String> _unionAndPresence(
  Map<String, Json?> parsed,
  Structure structure,
  List<String> names,
  bool complete,
) {
  if (!complete) return const [];
  final errors = <String>[];
  for (final slot in structure.slots) {
    if (!names.contains(slot.fileName)) {
      errors.add(
        'V2 : ${slot.fileName} : fichier manquant (--complete exige les '
        '${structure.slots.length} séances)',
      );
    }
  }
  for (final technique in structure.partsByTechnique.keys) {
    final docs = [
      for (final d in parsed.values)
        if (d != null && d['technique'] == technique) d,
    ];
    if (docs.isEmpty) continue;
    final covered = <int>{};
    final parts = <int>{};
    for (final d in docs) {
      parts.add(_part(d));
      final training = d['training'];
      final exercises = training is Map ? training['exercises'] : null;
      if (exercises is! List) continue;
      for (final e in exercises) {
        final ref = e is Map ? e['ref'] : null;
        if (ref is Map && ref['n'] is int) covered.add(ref['n']! as int);
      }
    }
    final wanted = {
      for (final s in structure.slotsOf(technique)) ...s.exercises,
    };
    final missing = wanted.difference(covered).toList()..sort();
    if (missing.isNotEmpty) {
      errors.add(
        'V5 : $technique : exercices $missing couverts par aucune séance',
      );
    }
    final count = structure.partsByTechnique[technique]!;
    for (var k = 1; k <= count; k++) {
      if (!parts.contains(k)) {
        errors.add('V23 : $technique : partie $k absente (parties 1 à $count)');
      }
    }
  }
  return errors;
}
