@Tags(['tooling'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rejoue `scripts/sync_web_assets.dart --check` dans un faux dépôt (le script
/// déduit la racine de son propre emplacement) : le vrai arbre n'est jamais
/// touché et aucun téléchargement n'a lieu.
void main() {
  late Directory root;

  File file(String relative) => File('${root.path}/$relative');

  setUp(() {
    root = Directory.systemTemp.createTempSync('sync_web_assets_');
    Directory('${root.path}/scripts').createSync();
    File('../scripts/sync_web_assets.dart')
        .copySync('${root.path}/scripts/sync_web_assets.dart');
    file('app/pubspec.lock')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
packages:
  other:
    dependency: transitive
    description:
      name: other
    source: hosted
    version: "9.9.9"
  sqlite3:
    dependency: transitive
    description:
      name: sqlite3
      url: "https://pub.dev"
    source: hosted
    version: "3.5.2"
''');
    file('app/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'drift',
              'rootUri': '../../pkg/drift',
              'packageUri': 'lib/',
            },
          ],
        }),
      );
    file('pkg/drift/drift_worker.js')
      ..createSync(recursive: true)
      ..writeAsStringSync('worker v1');
    file('app/web/drift_worker.js')
      ..createSync(recursive: true)
      ..writeAsStringSync('worker v1');
    file('app/web/sqlite3.wasm').writeAsBytesSync([0, 0x61, 0x73, 0x6d, 1, 0]);
    file('app/web/sqlite3.wasm.version').writeAsStringSync('3.5.2\n');
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult run([String? argument]) => Process.runSync('dart', [
    '${root.path}/scripts/sync_web_assets.dart',
    ?argument,
  ]);

  test('the real web assets match the locked drift and sqlite3 versions', () {
    final result = Process.runSync('dart', [
      '../scripts/sync_web_assets.dart',
      '--check',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('--check passes on consistent assets', () {
    final result = run('--check');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect('${result.stdout}', contains('sqlite3.wasm 3.5.2'));
  });

  test('--check fails when drift_worker.js is not the one of the package', () {
    file('app/web/drift_worker.js').writeAsStringSync('worker v0');

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('différent'));
  });

  test('--check fails when drift_worker.js is missing', () {
    file('app/web/drift_worker.js').deleteSync();

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('drift_worker.js absent'));
  });

  test('--check fails when sqlite3.wasm is missing', () {
    file('app/web/sqlite3.wasm').deleteSync();

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('sqlite3.wasm absent'));
  });

  test('--check fails when sqlite3.wasm is not a WebAssembly module', () {
    file('app/web/sqlite3.wasm').writeAsStringSync('<html>');

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('WebAssembly'));
  });

  test('--check fails when sqlite3.wasm is of another version', () {
    file('app/web/sqlite3.wasm.version').writeAsStringSync('3.4.0\n');

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('3.4.0'));
  });

  test('--check fails when the version file is missing', () {
    file('app/web/sqlite3.wasm.version').deleteSync();

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('inconnue'));
  });

  test('--check fails without a resolved package configuration', () {
    file('app/.dart_tool/package_config.json').deleteSync();

    expect(run('--check').exitCode, 1);
  });

  test('--check fails when sqlite3 is not locked', () {
    file('app/pubspec.lock').writeAsStringSync('packages: {}\n');

    expect(run('--check').exitCode, 1);
  });

  test('--check never writes anything', () {
    file('app/web/drift_worker.js').writeAsStringSync('worker v0');

    run('--check');

    expect(file('app/web/drift_worker.js').readAsStringSync(), 'worker v0');
  });

  test('rejects an unknown argument', () {
    expect(run('--nope').exitCode, 2);
  });
}
