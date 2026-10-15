import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void _copy(String from, String to, {List<String> excludes = const []}) {
  Directory(to).createSync(recursive: true);
  final result = Process.runSync('rsync', [
    '-a',
    for (final exclude in excludes) '--exclude=$exclude',
    '$from/',
    '$to/',
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

void main() {
  test('check.sh --fast fails on an invalid catalogue sheet', () {
    // Le dépôt réel n'est jamais modifié : le garde-fou tourne sur une copie.
    final real = Directory('..').absolute.path;
    final copy = Directory.systemTemp.createTempSync('check_fast_sheet_');
    addTearDown(() => copy.deleteSync(recursive: true));

    _copy('$real/app', '${copy.path}/app', excludes: ['build/', 'coverage/']);
    _copy('$real/scripts', '${copy.path}/scripts');
    _copy('$real/docs/knowledge', '${copy.path}/docs/knowledge');
    _copy('$real/docs/sources', '${copy.path}/docs/sources');
    _copy('$real/seances', '${copy.path}/seances');

    // Corrompre la fiche à la source ET dans l'asset : l'étape de synchro
    // reste verte, seule l'étape de validation des fiches peut échouer.
    for (final path in [
      '${copy.path}/docs/knowledge/05-seances/catalogue/07-bille-pleine-1.yaml',
      '${copy.path}/app/assets/fiches/07-bille-pleine-1.yaml',
    ]) {
      final file = File(path);
      file.writeAsStringSync(
        file.readAsStringSync().replaceFirst('version: 1', 'version: 2'),
      );
    }

    final result = Process.runSync('bash', [
      '${copy.path}/scripts/check.sh',
      '--fast',
    ], workingDirectory: copy.path);

    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('Fiches de séance (FORMAT.md'));
    expect(result.stderr, contains('V1'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
