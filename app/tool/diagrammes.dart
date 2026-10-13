// Usage : cd app && dart run tool/diagrammes.dart [--ascii] [--summary]
//   <fichier.yaml...>
// Valide les diagrammes d'exercices (FORMAT.md) et les rend en ASCII.
import 'dart:io';

import 'diagrammes/cli.dart';

void main(List<String> args) {
  exit(runCli(args, out: stdout, err: stderr));
}
