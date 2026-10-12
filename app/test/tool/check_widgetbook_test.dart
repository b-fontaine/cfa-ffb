@Tags(['tooling'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rejoue `scripts/check_widgetbook.dart` sur de faux projets `app/` et
/// `widgetbook/`.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('check_widgetbook_'));

  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, String content) {
    File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  const card =
      'class Card extends StatelessWidget {}\n'
      'class _Private extends StatelessWidget {}\n';

  String useCase(String type, String function) =>
      "@widgetbook.UseCase(name: 'n', type: $type, path: '[Widgets]')\n"
      'Widget $function(BuildContext context) => const Placeholder();\n';

  ProcessResult run() => Process.runSync('dart', [
    '../scripts/check_widgetbook.dart',
    '${root.path}/app',
    '${root.path}/widgetbook',
  ]);

  test('accepts a widget covered by an up to date use case', () {
    write('app/lib/shared/ui/card.dart', card);
    write('widgetbook/lib/use_cases/card.dart', useCase('Card', 'buildCard'));
    write('widgetbook/lib/main.directories.g.dart', 'buildCard');

    final result = run();

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('1 widget(s), 1 use case(s)'));
  });

  test('rejects a public widget without a use case', () {
    write('app/lib/pages/p/presentation/card.dart', card);
    write(
      'widgetbook/lib/use_cases/other.dart',
      useCase('Other', 'buildOther'),
    );
    write('widgetbook/lib/main.directories.g.dart', 'buildOther');

    final result = run();

    expect(result.exitCode, 1);
    expect(result.stderr, contains('Aucun use case Widgetbook pour Card'));
  });

  test('ignores widgets outside the design system and the pages', () {
    write('app/lib/entities/a/data/hidden.dart', card);
    write('widgetbook/lib/main.directories.g.dart', '');

    expect(run().exitCode, 0);
  });

  test('rejects a use case missing from the generated directory', () {
    write('app/lib/shared/ui/card.dart', card);
    write('widgetbook/lib/use_cases/card.dart', useCase('Card', 'buildCard'));
    write('widgetbook/lib/main.directories.g.dart', 'nothing');

    final result = run();

    expect(result.exitCode, 1);
    expect(result.stderr, contains('Code généré obsolète : buildCard'));
  });

  test('requires the generated directory', () {
    write('app/lib/shared/ui/card.dart', card);
    write('widgetbook/lib/use_cases/card.dart', useCase('Card', 'buildCard'));

    final result = run();

    expect(result.exitCode, 1);
    expect(result.stderr, contains('main.directories.g.dart absent'));
  });
}
