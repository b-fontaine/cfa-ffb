import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rejoue `scripts/check_doc_links.dart` : tout lien relatif vers une ancre
/// d'un fichier Markdown de `docs/` doit viser un titre qui existe.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('check_doc_links_'));

  tearDown(() => dir.deleteSync(recursive: true));

  ProcessResult run(Map<String, String> files) {
    files.forEach((name, text) {
      File('${dir.path}/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    });
    return Process.runSync('dart', [
      '../scripts/check_doc_links.dart',
      dir.path,
    ]);
  }

  test('the real docs have no broken anchor, roadmap.md included', () {
    final result = Process.runSync('dart', [
      '../scripts/check_doc_links.dart',
      '../docs',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('liens OK'));
  });

  test('mutation: the old anchor of a renamed roadmap title fails', () {
    final result = run({
      'roadmap.md': '### Procédure de mise en service sur Firestore\n',
      'adr.md': '[x](roadmap.md#procédure-de-bascule-vers-firestore)\n',
    });

    expect(result.exitCode, 1);
    expect(result.stderr, contains('#procédure-de-bascule-vers-firestore'));
    expect(result.stderr, contains('adr.md:1'));
  });

  test('the renamed title and its accents resolve', () {
    final result = run({
      'roadmap.md': '### Procédure de mise en service sur Firestore\n',
      'adr.md': '[x](roadmap.md#procédure-de-mise-en-service-sur-firestore)\n',
    });

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('same-file anchors, repeated titles and code fences', () {
    final result = run({
      'a.md':
          '# Titre\n## Suite\n## Suite\n```\n# Fantôme\n```\n'
          '[1](#titre) [2](#suite-1) [3](#fantôme)\n',
    });

    expect(result.exitCode, 1);
    expect(result.stderr, contains('#fantôme'));
    expect(result.stderr, isNot(contains('#titre')));
    expect(result.stderr, isNot(contains('#suite-1')));
  });

  test('external links and links to missing files are not its concern', () {
    final result = run({
      'a.md': '[x](https://exemple.fr/#nope) [y](absent.md#nope)\n',
    });

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });
}
