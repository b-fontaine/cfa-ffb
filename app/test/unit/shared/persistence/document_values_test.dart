import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DocumentValues values(Map<String, Object?> fields) =>
      DocumentValues('clubs/c1/x/y', fields);

  Matcher failureNaming(String field) => throwsA(
    isA<ServiceFailure>()
        .having((f) => f.code, 'code', ServiceFailureCode.other)
        .having((f) => f.detail, 'detail', contains(field)),
  );

  test('reads well-typed values', () {
    final read = values({
      'name': 'a',
      'n': 4,
      'items': [1, 2],
      'at': DateTime(2026),
      'iso': '2026-09-01T10:00:00.000Z',
    });

    expect(read.string('name'), 'a');
    expect(read.optString('missing'), isNull);
    expect(read.integer('n', fallback: 0), 4);
    expect(read.integer('missing', fallback: 9), 9);
    expect(read.list('items'), [1, 2]);
    expect(read.list('missing'), isEmpty);
    expect(read.date('at'), DateTime(2026));
    expect(read.date('iso'), DateTime.utc(2026, 9, 1, 10));
    expect(read.optDate('missing'), isNull);
  });

  test('a wrong type names the field and nothing else', () {
    final read = values({'a': 1, 'b': 'x', 'c': 'not a date', 'd': 5});

    expect(() => read.string('a'), failureNaming('a'));
    expect(() => read.string('missing'), failureNaming('missing'));
    expect(() => read.optString('a'), failureNaming('a'));
    expect(() => read.integer('b', fallback: 0), failureNaming('b'));
    expect(() => read.list('a'), failureNaming('a'));
    expect(() => read.optDate('c'), failureNaming('c'));
    expect(() => read.optDate('d'), failureNaming('d'));
    expect(() => read.date('missing'), failureNaming('missing'));
  });

  test('a date round-trips with its zone and microseconds', () {
    for (final date in [
      DateTime(2026, 9, 1, 14, 30, 15, 123, 456),
      DateTime.utc(2028, 9, 1, 14, 30, 15, 123, 456),
    ]) {
      final decoded = DocumentValues.decodeDate(
        DocumentValues.encodeDate(date),
        'p',
        'f',
      )!;

      expect(decoded, date);
      expect(decoded.isUtc, date.isUtc);
    }
  });
}
