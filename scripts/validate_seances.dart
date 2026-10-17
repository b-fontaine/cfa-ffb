// Valide de façon déterministe les séances générées dans /seances.
//
// Règles vérifiées :
//   1. front matter présent avec `public` (enfants|adultes) et `duree_minutes`;
//   2. duree_minutes = 90 pour enfants, 120 pour adultes;
//   3. le déroulé minuté est contigu, commence à 0 et se termine à
//      duree_minutes;
//   4. chaque ligne du déroulé porte une étiquette de source [S], [FFB], [Web]
//      ou [Prop];
//   5. les phases « Notion », « Entraînement » et « Jeu » apparaissent dans
//      cet ordre.
//
// Usage : dart run scripts/validate_seances.dart [dossier]   (défaut : seances)
import 'dart:io';

const _durations = {'enfants': 90, 'adultes': 120};
final _row = RegExp(r'^\|\s*(\d+)\s*[–-]\s*(\d+)\s*\|(.*)\|\s*$');
final _tag = RegExp(r'\[(S|FFB|Web|Prop)\]');

List<String> validate(String path, String content) {
  final errors = <String>[];
  final lines = content.split('\n');

  final meta = <String, String>{};
  if (lines.isNotEmpty && lines.first.trim() == '---') {
    for (final line in lines.skip(1)) {
      if (line.trim() == '---') break;
      final i = line.indexOf(':');
      if (i > 0) {
        meta[line.substring(0, i).trim()] = line.substring(i + 1).trim();
      }
    }
  } else {
    errors.add('front matter manquant');
  }

  final public = meta['public'];
  final duration = int.tryParse(meta['duree_minutes'] ?? '');
  if (!_durations.containsKey(public)) {
    errors.add('public invalide : $public (enfants|adultes)');
  }
  if (duration == null) {
    errors.add('duree_minutes manquant ou invalide');
  } else if (_durations.containsKey(public) && _durations[public] != duration) {
    errors.add(
      'duree_minutes=$duration incompatible avec public=$public '
      '(attendu ${_durations[public]})',
    );
  }

  var cursor = 0;
  var rows = 0;
  var lastRank = -1;
  for (final line in lines) {
    final m = _row.firstMatch(line);
    if (m == null) continue;
    rows++;
    final start = int.parse(m.group(1)!);
    final end = int.parse(m.group(2)!);
    final rest = m.group(3)!;
    if (start != cursor) {
      errors.add(
        'déroulé non contigu : ligne attendue à $cursor, trouvée à $start',
      );
    }
    if (end <= start) errors.add('plage invalide $start–$end');
    cursor = end;
    if (!_tag.hasMatch(rest)) {
      errors.add(
        'ligne $start–$end sans étiquette de source [S]/[FFB]/[Web]/[Prop]',
      );
    }
    final low = rest.toLowerCase();
    final rank = low.contains('notion')
        ? 1
        : low.contains('entra')
        ? 2
        : low.contains('jeu')
        ? 3
        : -1;
    if (rank != -1) {
      if (rank < lastRank) {
        errors.add('ordre des phases non respecté près de $start–$end');
      }
      lastRank = rank;
    }
  }
  if (rows == 0) errors.add('déroulé minuté introuvable');
  if (duration != null && rows > 0 && cursor != duration) {
    errors.add('le déroulé se termine à $cursor min au lieu de $duration min');
  }
  return errors;
}

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args.first : 'seances');
  if (!dir.existsSync()) {
    stderr.writeln('dossier introuvable : ${dir.path}');
    exit(2);
  }
  var failed = 0;
  var count = 0;
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    count++;
    final errors = validate(f.path, f.readAsStringSync());
    if (errors.isNotEmpty) {
      failed++;
      stderr.writeln('✗ ${f.path}');
      for (final e in errors) {
        stderr.writeln('    - $e');
      }
    } else {
      stdout.writeln('✓ ${f.path}');
    }
  }
  stdout.writeln('$count séance(s), $failed en échec');
  exit(failed == 0 ? 0 : 1);
}
