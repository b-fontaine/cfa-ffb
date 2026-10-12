import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  group('construction', () {
    test('accepts blocks in strictly increasing teaching order', () {
      expect(buildCatalogue().blocks.map((b) => b.id), ['a', 'b', 'c']);
    });

    test('refuses an empty catalogue', () {
      expect(
        () => buildCatalogue([]),
        violation(InvariantCode.invalidCatalogue),
      );
    });

    test('refuses duplicate block ids', () {
      expect(
        () => buildCatalogue([block('a', 1), block('a', 2)]),
        violation(InvariantCode.invalidCatalogue),
      );
    });

    test('refuses equal teaching orders', () {
      expect(
        () => buildCatalogue([block('a', 1), block('b', 1)]),
        violation(InvariantCode.invalidCatalogue),
      );
    });

    test('refuses blocks listed out of teaching order', () {
      expect(
        () => buildCatalogue([block('a', 2), block('b', 1)]),
        violation(InvariantCode.invalidCatalogue),
      );
    });

    test('accepts a single block', () {
      expect(buildCatalogue([block('a', 1)]).blocks, hasLength(1));
    });

    test('refuses a default passes count of 0', () {
      expect(
        () => ExerciseCatalogue(
          version: 1,
          level: 1,
          defaultPassesRequired: 0,
          blocks: [block('a', 1)],
        ),
        violation(InvariantCode.invalidCatalogue),
      );
    });
  });

  group('lookups', () {
    final cat = buildCatalogue();

    test('finds a block by id', () {
      expect(cat.blockById('b')!.teachingOrder, 2);
    });

    test('returns null for an unknown block', () {
      expect(cat.blockById('zzz'), isNull);
    });

    test('finds an exercise by reference', () {
      expect(cat.exercise(ref('b', 2))!.ref, ref('b', 2));
    });

    test('returns null for a number past the end of the block', () {
      expect(cat.exercise(ref('b', 4)), isNull);
    });

    test('returns null for an exercise of an unknown block', () {
      expect(cat.exercise(ref('zzz', 1)), isNull);
    });

    test('lists all exercises in teaching order', () {
      expect(cat.exercises, hasLength(9));
      expect(cat.exercises.first.ref, ref('a', 1));
      expect(cat.exercises.last.ref, ref('c', 3));
    });

    test('exposes the required rate of every exercise', () {
      expect(cat.rates, hasLength(9));
      expect(cat.rates[ref('c', 2)], rate());
    });
  });

  group('nextExercise', () {
    final cat = buildCatalogue();

    test('is the first exercise when nothing is validated', () {
      expect(cat.nextExercise(validated: {}), ref('a', 1));
    });

    test('is the following exercise of the block', () {
      expect(cat.nextExercise(validated: {ref('a', 1)}), ref('a', 2));
    });

    test('moves to the first exercise of the next block', () {
      final validated = {ref('a', 1), ref('a', 2), ref('a', 3)};

      expect(cat.nextExercise(validated: validated), ref('b', 1));
    });

    test('never skips an unvalidated exercise', () {
      final validated = {ref('a', 2), ref('a', 3), ref('b', 1)};

      expect(cat.nextExercise(validated: validated), ref('a', 1));
    });

    test('is null when the whole level is validated', () {
      final validated = {for (final spec in cat.exercises) spec.ref};

      expect(cat.nextExercise(validated: validated), isNull);
    });

    test('follows the teaching order, not the list order of the source', () {
      final reordered = buildCatalogue([block('x', 1), block('y', 2)]);

      expect(reordered.nextExercise(validated: {ref('x', 3)}), ref('x', 1));
    });
  });
}
