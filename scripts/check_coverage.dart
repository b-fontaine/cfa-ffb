// Vérifie la couverture de lignes à partir de app/coverage/lcov.info.
//
// - exclut le code généré (*.g.dart, *.freezed.dart, *.config.dart,
//   *.steps.dart, l10n) ;
// - exclut le câblage listé dans `_excluded` (couvert par les tests BDD) ;
// - échoue si un fichier de lib/ n'est jamais chargé par les tests (lcov omet les
//   fichiers sans ligne instrumentée, ex. interfaces : ils sont tolérés tant
//   qu'un fichier chargé les importe) ;
// - échoue si le taux global est inférieur au seuil.
//
// Usage : dart run scripts/check_coverage.dart [seuil=90] [app]
import 'dart:io';

const _excluded = <String>{'lib/main.dart', 'lib/app/di/injection.dart'};

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.steps.dart') ||
    path.contains('/l10n/generated/');

void main(List<String> args) {
  final threshold = args.isNotEmpty ? double.parse(args[0]) : 90.0;
  final appDir = args.length > 1 ? args[1] : 'app';
  final lcov = File('$appDir/coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('lcov.info introuvable : lancer flutter test --coverage.');
    exit(2);
  }

  final found = <String, (int, int)>{};
  String? current;
  var lines = 0;
  var hit = 0;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/');
      lines = 0;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      lines = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit = int.parse(line.substring(3));
    } else if (line == 'end_of_record' && current != null) {
      found[current] = (lines, hit);
    }
  }

  var failed = false;
  final expected =
      Directory('$appDir/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/').substring(appDir.length + 1))
          .where((p) => p.endsWith('.dart'))
          .where((p) => !_isGenerated(p) && !_excluded.contains(p))
          .toList()
        ..sort();

  // Fichiers importés par un fichier chargé (ou par le câblage exclu).
  final importRe = RegExp(
    r'''^\s*(?:import|export)\s+['"]package:[^/]+/([^'"]+)['"]''',
    multiLine: true,
  );
  final referenced = <String>{};
  for (final path in [...found.keys, ..._excluded]) {
    final file = File('$appDir/$path');
    if (!file.existsSync()) continue;
    for (final m in importRe.allMatches(file.readAsStringSync())) {
      referenced.add('lib/${m.group(1)}');
    }
  }
  // Fermeture transitive : un fichier sans ligne instrumentée peut en
  // importer d'autres.
  var grew = true;
  while (grew) {
    grew = false;
    for (final path in referenced.toList()) {
      if (found.containsKey(path)) continue;
      final file = File('$appDir/$path');
      if (!file.existsSync()) continue;
      for (final m in importRe.allMatches(file.readAsStringSync())) {
        grew = referenced.add('lib/${m.group(1)}') || grew;
      }
    }
  }

  var totalLines = 0;
  var totalHit = 0;
  for (final path in expected) {
    final entry = found[path];
    if (entry == null) {
      if (!referenced.contains(path)) {
        stderr.writeln('NON CHARGÉ par les tests : $path');
        failed = true;
      }
      continue;
    }
    totalLines += entry.$1;
    totalHit += entry.$2;
    if (entry.$2 < entry.$1) {
      stdout.writeln('  ${entry.$2}/${entry.$1}  $path');
    }
  }

  final rate = totalLines == 0 ? 100.0 : 100 * totalHit / totalLines;
  stdout.writeln(
    'Couverture lignes : ${rate.toStringAsFixed(1)} % '
    '($totalHit/$totalLines, seuil $threshold %)',
  );
  if (rate < threshold) {
    stderr.writeln('Couverture insuffisante.');
    failed = true;
  }
  if (failed) exit(1);
}
