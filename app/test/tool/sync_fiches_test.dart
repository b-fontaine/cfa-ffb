import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _source = 'docs/knowledge/05-seances/catalogue';
const _target = 'app/assets/fiches';

const _session = 'version: 1\nid: posture-1\n';

/// Rejoue `scripts/sync_fiches.sh` dans un faux dépôt (le script déduit la
/// racine de son propre emplacement) : le vrai arbre n'est jamais touché.
void main() {
  late Directory root;

  File source(String relative, String text) =>
      File('${root.path}/$_source/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);

  File asset(String relative) => File('${root.path}/$_target/$relative');

  void pubspec({bool declared = true}) => File('${root.path}/app/pubspec.yaml')
      .writeAsStringSync(
        'flutter:\n  assets:\n${declared ? '    - assets/fiches/\n' : ''}',
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('sync_fiches_');
    Directory('${root.path}/scripts').createSync();
    File('../scripts/sync_fiches.sh')
        .copySync('${root.path}/scripts/sync_fiches.sh');
    Directory('${root.path}/app').createSync();
    pubspec();
    source('01-posture-1.yaml', _session);
    source('02-posture-2.yaml', '$_session# deux\n');
    source('FORMAT.md', '# format\n');
    source('notes.yaml', 'a: 1\n');
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult run([String? argument]) => Process.runSync('bash', [
    '${root.path}/scripts/sync_fiches.sh',
    ?argument,
  ]);

  test('the real assets are a byte for byte copy of the catalogue', () {
    final result = Process.runSync('bash', [
      '../scripts/sync_fiches.sh',
      '--check',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('copies the session files only', () {
    expect(run().exitCode, 0);

    expect(asset('01-posture-1.yaml').readAsStringSync(), _session);
    expect(asset('02-posture-2.yaml').existsSync(), isTrue);
    expect(asset('FORMAT.md').existsSync(), isFalse);
    expect(asset('notes.yaml').existsSync(), isFalse);
  });

  test('removes a stale asset on the next copy', () {
    run();
    asset('09-ancienne-1.yaml').writeAsStringSync(_session);

    run();

    expect(asset('09-ancienne-1.yaml').existsSync(), isFalse);
  });

  test('--check passes on an identical copy', () {
    run();

    expect(run('--check').exitCode, 0);
  });

  test('--check fails when an asset differs by one byte', () {
    run();
    asset('01-posture-1.yaml').writeAsStringSync('$_session ');

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('sync_fiches.sh'));
  });

  test('--check fails when an asset is missing', () {
    run();
    asset('02-posture-2.yaml').deleteSync();

    expect(run('--check').exitCode, 1);
  });

  test('--check fails when an asset has no source any more', () {
    run();
    asset('03-posture-3.yaml').writeAsStringSync(_session);

    expect(run('--check').exitCode, 1);
  });

  test('--check fails when the source gains a session', () {
    run();
    source('03-puissance-1.yaml', _session);

    expect(run('--check').exitCode, 1);
  });

  test('--check fails when the folder is not declared in the pubspec', () {
    run();
    pubspec(declared: false);

    final result = run('--check');

    expect(result.exitCode, 1);
    expect('${result.stderr}', contains('assets/fiches/'));
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

  test('fails when the source holds no session at all', () {
    File('${root.path}/$_source/01-posture-1.yaml').deleteSync();
    File('${root.path}/$_source/02-posture-2.yaml').deleteSync();

    expect(run().exitCode, 1);
  });

  test('rejects an unknown argument', () {
    expect(run('--nope').exitCode, 2);
  });
}
