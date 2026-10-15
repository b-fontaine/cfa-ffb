// Usage : cd app && dart run tool/fiches.dart [--complete] [--structure]
//   [<fichier.yaml>...]
// Valide les séances du catalogue (docs/knowledge/05-seances/catalogue,
// FORMAT.md § 7). Sans fichier : tout le dossier ; --complete exige les 28
// séances ; --structure affiche la structure calculée depuis le catalogue.
import 'dart:io';

import 'fiches/cli.dart';

void main(List<String> args) {
  exit(runCli(args, out: stdout, err: stderr));
}
