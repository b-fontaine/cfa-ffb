import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rejoue `scripts/check_family_register.dart` : chaque chemin de
/// `scripts/rules_test/family_reads.json` (listes `famille` et `connexion`)
/// doit être nommé, entre apostrophes inverses, dans le traitement 1 bis du
/// registre des traitements.
void main() {
  const readsPath = '../scripts/rules_test/family_reads.json';
  const registerPath =
      '../docs/engineering/conformite/registre-des-traitements.md';
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('check_register_'));

  tearDown(() => dir.deleteSync(recursive: true));

  ProcessResult run(String reads, String register) => Process.runSync('dart', [
    '../scripts/check_family_register.dart',
    reads,
    register,
  ]);

  String copyRegister(String Function(String) edit) {
    final copy = File('${dir.path}/registre.md')
      ..writeAsStringSync(edit(File(registerPath).readAsStringSync()));
    return copy.path;
  }

  test('the real register names every path of the real reads list', () {
    final result = run(readsPath, registerPath);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('registre OK'));
  });

  test('mutation: a collection no longer named in the register fails', () {
    final mutated = copyRegister(
      (text) => text.replaceAll('`acquisitions`', 'acquisitions'),
    );

    final result = run(readsPath, mutated);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('acquisitions'));
  });

  test('mutation: a connection read no longer named fails too', () {
    final mutated = copyRegister(
      (text) => text.replaceAll('`admins/{uid}`', 'admins'),
    );

    final result = run(readsPath, mutated);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('admins/{uid}'));
  });

  test('a mention outside the family space section does not count', () {
    final mutated = copyRegister(
      (text) => text
          .replaceAll('`attempts`', 'attempts')
          .replaceFirst('## Traitement 3 —', '`attempts`\n\n## Traitement 3 —'),
    );

    final result = run(readsPath, mutated);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('attempts'));
  });

  test('a new path added to the reads list must be named', () {
    final reads = File('${dir.path}/reads.json')
      ..writeAsStringSync('''
{"famille": ["get clubs/{club}/students/{student}", "get clubs/{club}/novelties/{n}"],
 "connexion": [], "interdit": []}''');

    final result = run(reads.path, registerPath);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('novelties'));
  });
}
