import 'dart:io';

import 'ascii_renderer.dart';
import 'ghosts.dart';
import 'summary.dart';
import 'validator.dart';

const _usage =
    'Usage : dart run tool/diagrammes.dart [--ascii] [--summary] [--ghosts] '
    '<fichier.yaml...>';

/// Exécute l'outil ; retourne le code de sortie (0 ok, 1 erreur de
/// validation, 2 erreur d'usage ou fichier illisible).
int runCli(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) {
  var ascii = false;
  var summary = false;
  var ghosts = false;
  final files = <String>[];
  for (final a in args) {
    switch (a) {
      case '--ascii':
        ascii = true;
      case '--summary':
        summary = true;
      case '--ghosts':
        ghosts = true;
      default:
        if (a.startsWith('--')) {
          err.writeln('Option inconnue : $a\n$_usage');
          return 2;
        }
        files.add(a);
    }
  }
  if (files.isEmpty) {
    err.writeln(_usage);
    return 2;
  }
  var code = 0;
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      err.writeln('$path : fichier introuvable');
      code = 2;
      continue;
    }
    final text = file.readAsStringSync();
    final report = validateDiagramFile(text);
    if (report.errors.isNotEmpty) {
      for (final e in report.errors) {
        err.writeln('$path: $e');
      }
      if (code == 0) code = 1;
      continue;
    }
    if (ghosts) {
      // Lecture seule : les cercles `impact` d'une proposition sont au `G`
      // calculé (G = O - (r_c + r_o) · u), à 0,01 case près.
      final mismatches = ghostMismatches(text);
      for (final m in mismatches) {
        err.writeln('$path: $m');
      }
      if (mismatches.isNotEmpty && code == 0) code = 1;
    }
    if (!ascii && !summary) {
      out.writeln(
        'OK $path (${report.diagrams.length} diagramme(s), '
        '${report.warnings.length} avertissement(s))',
      );
    }
    for (final d in report.diagrams) {
      if (summary) out.writeln(summaryLine(d));
      if (ascii) out.writeln('${renderAscii(d)}\n');
    }
    if (!ascii) {
      for (final w in report.warnings) {
        out.writeln('$path: AVERTISSEMENT $w');
      }
    }
  }
  return code;
}
