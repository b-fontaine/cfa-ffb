// Usage : dart run tool/check_indexes.dart  (depuis app/)
import 'dart:io';

import 'indexes/index_rules.dart';

void main() {
  final lib = Directory('lib');
  final indexes = File('../firestore.indexes.json');
  if (!lib.existsSync() || !indexes.existsSync()) {
    stderr.writeln(
      'Exécuter depuis app/ (lib/ ou ../firestore.indexes.json introuvable).',
    );
    exit(2);
  }
  final violations = checkIndexes(lib: lib, indexesFile: indexes);
  if (violations.isEmpty) {
    stdout.writeln('Index Firestore OK (chaque requête a son index déclaré).');
    return;
  }
  violations.forEach(stderr.writeln);
  stderr.writeln(
    '${violations.length} index manquant(s) dans firestore.indexes.json.',
  );
  exit(1);
}
