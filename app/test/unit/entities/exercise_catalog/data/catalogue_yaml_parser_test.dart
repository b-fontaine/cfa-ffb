import 'package:billard_cfa/entities/exercise_catalog/data/catalogue_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

const _yaml = '''
version: 2
level: 1
validation:
  passes_required_default: 5
blocks:
  - id: second
    teaching_order: 2
    title: Second bloc
    sessions: {min: 2, max: 3}
    technical_sheet: [7, 8]
    duplicate_in_source: true
    exercises:
      - {n: 1, rate: [3, 5]}
  - id: first
    teaching_order: 1
    title: Premier bloc
    sessions: {min: 1, max: 2}
    technical_sheet: 4
    exercises:
      - {n: 1, rate: [7, 9], bridge: cadre, bronze: true, note: "8 billes"}
      - {n: 2, rate: [5, 10], bridge: surface}
''';

void main() {
  final parsed = parseCatalogue(_yaml);

  test('reads the header', () {
    expect(parsed.version, 2);
    expect(parsed.level, 1);
    expect(parsed.defaultPassesRequired, 5);
  });

  test('orders blocks by teaching_order, not by file order', () {
    expect(parsed.blocks.map((b) => b.id), ['first', 'second']);
  });

  test('reads sessions, sheets and the duplicate flag', () {
    final first = parsed.blockById('first')!;
    final second = parsed.blockById('second')!;

    expect(first.recommendedSessions.min, 1);
    expect(first.recommendedSessions.max, 2);
    expect(first.technicalSheets, [4]);
    expect(first.duplicateInSource, isFalse);
    expect(second.technicalSheets, [7, 8]);
    expect(second.duplicateInSource, isTrue);
  });

  test('reads exercises with rate, bridge, bronze and note', () {
    final spec = parsed.exercise(ref('first', 1))!;

    expect(spec.rate, rate(7, 9));
    expect(spec.bridge, Bridge.frame);
    expect(spec.bronze, isTrue);
    expect(spec.note, '8 billes');
  });

  test('defaults optional exercise fields', () {
    final spec = parsed.exercise(ref('second', 1))!;

    expect(spec.bridge, isNull);
    expect(spec.bronze, isFalse);
    expect(spec.note, isNull);
  });

  test('maps the surface bridge', () {
    expect(parsed.exercise(ref('first', 2))!.bridge, Bridge.surface);
  });

  test('rejects a document that is not a catalogue', () {
    expect(
      () => parseCatalogue('- a\n- b'),
      violation(InvariantCode.invalidCatalogue),
    );
  });

  test('rejects a missing field', () {
    expect(
      () => parseCatalogue('version: 1\nlevel: 1\nblocks: []'),
      violation(InvariantCode.invalidCatalogue),
    );
  });

  test('rejects an unknown bridge', () {
    final bad = _yaml.replaceFirst('bridge: surface', 'bridge: inconnu');

    expect(
      () => parseCatalogue(bad),
      violation(InvariantCode.invalidCatalogue),
    );
  });

  test('lets a domain violation through (rate above 16 attempts)', () {
    final bad = _yaml.replaceFirst('rate: [3, 5]', 'rate: [3, 17]');

    expect(
      () => parseCatalogue(bad),
      violation(InvariantCode.successRateOutOfRange),
    );
  });
}
