import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rejoue `scripts/check_l10n.dart` sur un faux dossier de fichiers ARB.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('check_l10n_'));

  tearDown(() => dir.deleteSync(recursive: true));

  void arb(String name, String json) =>
      File('${dir.path}/$name.arb').writeAsStringSync(json);

  ProcessResult run() =>
      Process.runSync('dart', ['../scripts/check_l10n.dart', dir.path]);

  test('accepts identical keys, whatever the metadata', () {
    arb('app_en', '{"@@locale":"en","a":"A","@a":{},"b":"B"}');
    arb('app_fr', '{"@@locale":"fr","a":"A","b":"B","@b":{}}');

    final result = run();

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('2 clés identiques'));
  });

  test('rejects a key missing from a language', () {
    arb('app_en', '{"a":"A","b":"B"}');
    arb('app_fr', '{"a":"A"}');

    final result = run();

    expect(result.exitCode, 1);
    expect(result.stderr, contains('clé manquante "b"'));
  });

  test('rejects an extra key in a language', () {
    arb('app_en', '{"a":"A"}');
    arb('app_fr', '{"a":"A","c":"C"}');

    final result = run();

    expect(result.exitCode, 1);
    expect(result.stderr, contains('clé en trop "c"'));
  });

  test('requires at least two languages', () {
    arb('app_en', '{"a":"A"}');

    final result = run();

    expect(result.exitCode, 2);
    expect(result.stderr, contains('Au moins deux fichiers'));
  });
}
