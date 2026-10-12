import 'package:flutter_test/flutter_test.dart';

import '../../../scripts/mutation_report.dart';

const _markdown = '''
# Mutation report

| Key           | Value                     |
| ------------- | ------------------------- |
| Rules         | worker.xml           |
| Mutations     | 8                        |
| Undetected    | 2                        |
''';

const _xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<undetected-mutations>
<file name="lib/a.dart">
<mutation line="7">
<original>  if (a &lt;= b) {</original>
<modified>  if (a &lt; b) {</modified>
</mutation>
</file>
<file name="lib/b.dart">
</file>
<file name="lib/c.dart">
<mutation line="3">
<original>  x = &quot;a&quot; &amp;&amp; y;</original>
<modified>  x = &quot;a&quot; || y;</modified>
</mutation>
</file>
</undetected-mutations>
''';

void main() {
  group('parsePart', () {
    test('reads the total and every undetected mutant', () {
      final part = parsePart(markdown: _markdown, xml: _xml);

      expect(part.total, 8);
      expect(part.undetected, 2);
      expect(part.mutants.first.file, 'lib/a.dart');
      expect(part.mutants.first.line, 7);
      expect(part.mutants.first.original.trim(), 'if (a <= b) {');
      expect(part.mutants.first.mutated.trim(), 'if (a < b) {');
      expect(part.mutants.last.original, contains('"a" && y'));
    });

    test('rejects a report without totals', () {
      expect(
        () => parsePart(markdown: 'nothing', xml: _xml),
        throwsFormatException,
      );
    });
  });

  group('MutationSummary', () {
    test('computes the detection score', () {
      final part = parsePart(markdown: _markdown, xml: _xml);

      expect(part.detected, 6);
      expect(part.score, 75);
    });

    test('is 100 % when there is no mutation', () {
      const empty = MutationSummary(0, []);

      expect(empty.score, 100);
    });

    test('merge adds the totals and sorts mutants by file then line', () {
      const late = UndetectedMutant('lib/z.dart', 1, 'a', 'b');
      const second = UndetectedMutant('lib/a.dart', 9, 'a', 'b');
      const first = UndetectedMutant('lib/a.dart', 2, 'a', 'b');

      final merged = merge([
        const MutationSummary(10, [late, second]),
        const MutationSummary(5, [first]),
      ]);

      expect(merged.total, 15);
      expect(merged.mutants, [first, second, late]);
      expect(merged.score, 80);
    });
  });

  group('totalMismatch', () {
    test('accepts the expected total', () {
      expect(totalMismatch(const MutationSummary(8, []), 8), isNull);
    });

    test('reports a lost or extra mutant', () {
      expect(totalMismatch(const MutationSummary(7, []), 8), contains('7'));
      expect(totalMismatch(const MutationSummary(9, []), 8), contains('8'));
    });
  });

  group('render', () {
    test('lists the score, the threshold and each undetected mutant', () {
      final text = render(
        parsePart(markdown: _markdown, xml: _xml),
        threshold: 85,
      );

      expect(text, contains('Score : 75.0 %'));
      expect(text, contains('Seuil : 85 %'));
      expect(text, contains('`lib/a.dart:7`'));
      expect(text, contains('`lib/c.dart:3`'));
    });

    test('omits the mutant section when everything is detected', () {
      final text = render(const MutationSummary(4, []), threshold: 80);

      expect(text, isNot(contains('non détectés')));
      expect(text, contains('Score : 100.0 %'));
    });
  });

  test('UndetectedMutant prints file, line and the change', () {
    const mutant = UndetectedMutant('lib/a.dart', 4, ' a ', ' b ');

    expect(mutant.toString(), 'lib/a.dart:4  - a  + b');
  });
}
