import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  test('accepts a block id and a number from 1', () {
    final ref = ExerciseRef(blockId: 'puissance', number: 1);

    expect(ref.blockId, 'puissance');
    expect(ref.number, 1);
  });

  test('refuses number 0', () {
    expect(
      () => ExerciseRef(blockId: 'a', number: 0),
      violation(InvariantCode.invalidExerciseRef),
    );
  });

  test('refuses a blank block id', () {
    expect(
      () => ExerciseRef(blockId: '  ', number: 1),
      violation(InvariantCode.invalidExerciseRef),
    );
  });

  test('is equal by value and usable in sets', () {
    expect(
      ExerciseRef(blockId: 'a', number: 2),
      ExerciseRef(blockId: 'a', number: 2),
    );
    expect({
      ExerciseRef(blockId: 'a', number: 2),
      ExerciseRef(blockId: 'a', number: 2),
    }, hasLength(1));
    expect(
      ExerciseRef(blockId: 'a', number: 2) ==
          ExerciseRef(blockId: 'a', number: 3),
      isFalse,
    );
  });

  group('tryParse', () {
    test('builds a reference from address segments', () {
      expect(
        ExerciseRef.tryParse('puissance', '3'),
        ExerciseRef(blockId: 'puissance', number: 3),
      );
    });

    test('returns null for a non numeric number', () {
      expect(ExerciseRef.tryParse('puissance', 'abc'), isNull);
    });

    test('returns null for a number below one', () {
      expect(ExerciseRef.tryParse('puissance', '0'), isNull);
      expect(ExerciseRef.tryParse('puissance', '-2'), isNull);
    });

    test('returns null for a blank block id', () {
      expect(ExerciseRef.tryParse(' ', '1'), isNull);
    });
  });
}
