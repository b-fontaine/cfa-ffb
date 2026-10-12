// Usage : dart run tool/check_architecture.dart
import 'dart:io';

import 'architecture/architecture_rules.dart';

void main() {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('Exécuter depuis app/ (dossier lib/ introuvable).');
    exit(2);
  }
  final violations = checkArchitecture(lib);
  if (violations.isEmpty) {
    stdout.writeln('Architecture OK (FSD + Clean).');
    return;
  }
  violations.forEach(stderr.writeln);
  stderr.writeln("${violations.length} violation(s) d'architecture.");
  exit(1);
}
