// Vérifie que tous les fichiers ARB ont exactement les mêmes clés.
//
// Usage : dart run scripts/check_l10n.dart [dossier=app/lib/shared/l10n]
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args[0] : 'app/lib/shared/l10n');
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.length < 2) {
    stderr.writeln('Au moins deux fichiers .arb attendus dans ${dir.path}.');
    exit(2);
  }

  Set<String> keys(File f) {
    final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    return json.keys.where((k) => !k.startsWith('@')).toSet();
  }

  final reference = keys(files.first);
  var failed = false;
  for (final file in files.skip(1)) {
    final other = keys(file);
    for (final missing in reference.difference(other)) {
      stderr.writeln('${file.path} : clé manquante "$missing"');
      failed = true;
    }
    for (final extra in other.difference(reference)) {
      stderr.writeln('${file.path} : clé en trop "$extra"');
      failed = true;
    }
  }
  if (failed) exit(1);
  stdout.writeln(
    'l10n OK : ${reference.length} clés identiques '
    'dans ${files.length} langues.',
  );
}
