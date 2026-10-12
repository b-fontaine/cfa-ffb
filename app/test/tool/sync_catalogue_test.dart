@Tags(['tooling'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _source = 'docs/knowledge/03-exercices/catalogue-entrainement.yaml';
const _asset = 'app/assets/catalogue/catalogue-entrainement.yaml';

/// Rejoue `scripts/sync_catalogue.sh` dans un faux dépôt (le script déduit la
/// racine de son propre emplacement) : le vrai arbre n'est jamais touché.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sync_catalogue_');
    Directory('${root.path}/scripts').createSync();
    File('../scripts/sync_catalogue.sh')
        .copySync('${root.path}/scripts/sync_catalogue.sh');
    File('${root.path}/$_source')
      ..createSync(recursive: true)
      ..writeAsStringSync('version: 1\n');
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult run([String? argument]) => Process.runSync('bash', [
    '${root.path}/scripts/sync_catalogue.sh',
    ?argument,
  ]);

  test('the real asset is a byte for byte copy of the knowledge base', () {
    final result = Process.runSync('bash', [
      '../scripts/sync_catalogue.sh',
      '--check',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('copies the source into the asset', () {
    expect(run().exitCode, 0);

    expect(File('${root.path}/$_asset').readAsStringSync(), 'version: 1\n');
  });

  test('--check passes on an identical copy', () {
    run();

    expect(run('--check').exitCode, 0);
  });

  test('--check fails when the asset differs by one byte', () {
    run();
    File('${root.path}/$_asset').writeAsStringSync('version: 2\n');

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('sync_catalogue.sh'));
  });

  test('--check fails when the asset is missing', () {
    expect(run('--check').exitCode, 1);
  });

  test('--check never writes the asset', () {
    run('--check');

    expect(File('${root.path}/$_asset').existsSync(), isFalse);
  });

  test('rejects an unknown argument', () {
    expect(run('--nope').exitCode, 2);
  });
}
