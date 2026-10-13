import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _source = 'docs/knowledge/03-exercices/diagrammes';
const _target = 'app/assets/diagrammes';

const _table = '''
version: 1
diagrams:
  - id: x
    kind: exercise
''';
const _game = '''
version: 1
diagrams:
  - id: x
    kind: game
''';
const _photo = '''
version: 1
diagrams:
  - id: x
    kind: technique-photo
''';

/// Rejoue `scripts/sync_diagrammes.sh` dans un faux dépôt (le script déduit la
/// racine de son propre emplacement) : le vrai arbre n'est jamais touché.
void main() {
  late Directory root;

  File source(String relative, String text) =>
      File('${root.path}/$_source/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);

  File asset(String relative) => File('${root.path}/$_target/$relative');

  /// Pubspec du faux dépôt : déclare les dossiers d'assets donnés.
  void pubspec(List<String> folders) => File('${root.path}/app/pubspec.yaml')
      .writeAsStringSync(
        'flutter:\n  assets:\n'
        '${folders.map((f) => '    - assets/diagrammes/$f/\n').join()}',
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('sync_diagrammes_');
    Directory('${root.path}/scripts').createSync();
    File('../scripts/sync_diagrammes.sh')
        .copySync('${root.path}/scripts/sync_diagrammes.sh');
    Directory('${root.path}/app').createSync();
    pubspec(['entrainement', 'jeux']);
    source('entrainement/p01.yaml', _table);
    source('jeux/p02.yaml', _game);
    source('techniques/p03.yaml', _photo);
    source('FORMAT.md', '# format\n');
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult run([String? argument]) => Process.runSync('bash', [
    '${root.path}/scripts/sync_diagrammes.sh',
    ?argument,
  ]);

  test('the real assets are a byte for byte copy of the knowledge base', () {
    final result = Process.runSync('bash', [
      '../scripts/sync_diagrammes.sh',
      '--check',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('copies the pages that carry a table, keeping the folders', () {
    expect(run().exitCode, 0);

    expect(asset('entrainement/p01.yaml').readAsStringSync(), _table);
    expect(asset('jeux/p02.yaml').readAsStringSync(), _game);
  });

  test('leaves out pages without table and non yaml files', () {
    run();

    expect(asset('techniques/p03.yaml').existsSync(), isFalse);
    expect(asset('FORMAT.md').existsSync(), isFalse);
  });

  test('removes a stale asset on the next copy', () {
    run();
    asset('jeux/p99.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(_game);

    run();

    expect(asset('jeux/p99.yaml').existsSync(), isFalse);
  });

  test('--check passes on an identical copy', () {
    run();

    expect(run('--check').exitCode, 0);
  });

  test('--check fails when an asset differs by one byte', () {
    run();
    asset('jeux/p02.yaml').writeAsStringSync('$_game ');

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('sync_diagrammes.sh'));
  });

  test('--check fails when an asset is missing', () {
    run();
    asset('jeux/p02.yaml').deleteSync();

    expect(run('--check').exitCode, 1);
  });

  test('--check fails when an asset has no source any more', () {
    run();
    asset('jeux/p99.yaml').writeAsStringSync(_game);

    expect(run('--check').exitCode, 1);
  });

  test('--check fails when the source gains a page', () {
    run();
    source('initiation/p04.yaml', _table);

    expect(run('--check').exitCode, 1);
  });

  test('--check fails when a folder of assets is not declared', () {
    run();
    pubspec(['entrainement']);

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('assets/diagrammes/jeux/'));
    expect('${result.stderr}', contains('pubspec.yaml'));
  });

  test('--check fails when the pubspec is missing', () {
    run();
    File('${root.path}/app/pubspec.yaml').deleteSync();

    expect(run('--check').exitCode, 1);
  });

  test('--check never writes the assets', () {
    run('--check');

    expect(Directory('${root.path}/$_target').existsSync(), isFalse);
  });

  test('fails when the source holds no table at all', () {
    File('${root.path}/$_source/entrainement/p01.yaml').deleteSync();
    File('${root.path}/$_source/jeux/p02.yaml').deleteSync();

    expect(run().exitCode, 1);
  });

  test('rejects an unknown argument', () {
    expect(run('--nope').exitCode, 2);
  });
}
