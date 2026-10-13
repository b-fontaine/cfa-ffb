import 'dart:io';

import 'catalogue.dart';
import 'context.dart';
import 'directory.dart';
import 'format_table.dart';
import 'session_rules.dart';

const _usage =
    'Usage : dart run tool/fiches.dart [--complete] [--structure] '
    '[<fichier.yaml>...]';

/// Exécute l'outil ; retourne le code de sortie (0 ok, 1 erreur de
/// validation, 2 erreur d'usage ou fichier illisible). [root] est la racine
/// du dépôt (`..` depuis `app/`).
int runCli(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  String root = '..',
}) {
  var complete = false;
  var structureOnly = false;
  final files = <String>[];
  for (final a in args) {
    switch (a) {
      case '--complete':
        complete = true;
      case '--structure':
        structureOnly = true;
      default:
        if (a.startsWith('--')) {
          err.writeln('Option inconnue : $a\n$_usage');
          return 2;
        }
        files.add(a);
    }
  }
  if (complete && files.isNotEmpty) {
    err.writeln("--complete s'applique au dossier entier.\n$_usage");
    return 2;
  }
  final catalogue =
      '$root/docs/knowledge/03-exercices/catalogue-entrainement.yaml';
  if (!File(catalogue).existsSync()) {
    err.writeln('Catalogue introuvable : $catalogue (racine : $root)');
    return 2;
  }
  final context = FichesContext.load(root);
  if (context.structure.errors.isNotEmpty) {
    for (final e in context.structure.errors) {
      err.writeln('catalogue: $e');
    }
    return 1;
  }
  if (structureOnly) {
    _printStructure(context.structure, out);
    return 0;
  }
  final dir = '$root/docs/knowledge/05-seances/catalogue';
  return files.isEmpty
      ? _runDirectory(dir, context, complete, out, err)
      : _runFiles(files, context, out, err);
}

void _printStructure(Structure structure, StringSink out) {
  out.writeln('rang  séance  exercices  précédente');
  for (final s in structure.slots) {
    final range = s.exercises.length == 1
        ? '${s.exercises.first}'
        : '${s.exercises.first}-${s.exercises.last}';
    out.writeln(
      '${s.order.toString().padLeft(2, '0')}  ${s.id}  $range  '
      '${s.previous ?? '-'}',
    );
  }
}

int _runDirectory(
  String dir,
  FichesContext context,
  bool complete,
  StringSink out,
  StringSink err,
) {
  final report = validateDirectory(dir, context, complete: complete);
  var failed = false;
  for (final name in report.files) {
    final errors = report.errorsByFile[name]!;
    if (errors.isEmpty) {
      out.writeln('OK $name');
    } else {
      failed = true;
      for (final e in errors) {
        err.writeln('$name: $e');
      }
    }
  }
  for (final e in report.globalErrors) {
    failed = true;
    err.writeln('catalogue: $e');
  }
  final format = File('$dir/FORMAT.md');
  if (format.existsSync()) {
    final errors = checkFormatTables(
      format.readAsStringSync(),
      context.structure,
    );
    for (final e in errors) {
      failed = true;
      err.writeln('FORMAT.md: $e');
    }
  }
  if (report.files.isEmpty) {
    err.writeln('Aucune séance dans $dir');
    return 1;
  }
  return failed ? 1 : 0;
}

int _runFiles(
  List<String> files,
  FichesContext context,
  StringSink out,
  StringSink err,
) {
  var code = 0;
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      err.writeln('$path : fichier introuvable');
      code = 2;
      continue;
    }
    final name = path.split('/').last;
    final dir = file.parent.path;
    final errors = validateSession(
      file.readAsStringSync(),
      fileName: name,
      context: context,
      siblings: loadSiblings(dir),
    );
    if (errors.isEmpty) {
      out.writeln('OK $name');
    } else {
      for (final e in errors) {
        err.writeln('$name: $e');
      }
      if (code == 0) code = 1;
    }
  }
  return code;
}
