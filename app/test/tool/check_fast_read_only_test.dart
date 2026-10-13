import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Empreinte d'un arbre : chemin relatif -> type, taille et date de
/// modification. Une réécriture, même à l'identique, change la date.
Map<String, String> _snapshot(Directory root) {
  final snapshot = <String, String>{};
  final base = root.absolute.path;
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final stat = entity.statSync();
    final relative = entity.absolute.path.substring(base.length + 1);
    snapshot[relative] = '${stat.size}:${stat.modified}';
  }
  return snapshot;
}

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
  test('check.sh --fast never writes to the working tree', () {
    // Le dépôt réel n'est jamais modifié par ce test : le garde-fou tourne
    // sur une copie temporaire.
    final real = Directory('..').absolute.path;
    final copy = Directory.systemTemp.createTempSync('check_fast_');
    addTearDown(() => copy.deleteSync(recursive: true));

    _copy('$real/app', '${copy.path}/app', excludes: ['build/', 'coverage/']);
    _copy('$real/scripts', '${copy.path}/scripts');
    _copy('$real/docs/knowledge', '${copy.path}/docs/knowledge');
    _copy('$real/docs/sources', '${copy.path}/docs/sources');
    _copy('$real/seances', '${copy.path}/seances');

    final probe = File('${copy.path}/app/test/tool/zz_unformatted_probe.dart')
      ..writeAsStringSync('void   main( ) {  }\n');
    final before = _snapshot(copy);

    final result = Process.runSync('bash', [
      '${copy.path}/scripts/check.sh',
      '--fast',
    ], workingDirectory: copy.path);
    final after = _snapshot(copy);

    expect(
      result.exitCode,
      isNot(0),
      reason: 'the unformatted probe must make the format step fail',
    );
    expect(result.stdout, contains('Formatage'));
    expect(after, before);
    expect(probe.readAsStringSync(), 'void   main( ) {  }\n');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
