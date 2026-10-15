import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/features/run_sheet/domain/recall_exercise.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/session_sheet_fixtures.dart';

void main() {
  // posture-1 (1) → demi-bille-1 (2) → demi-bille-2 (3) → quart-1 (4).
  final sheets = catalogueFixture();
  SessionSheet sheet(String id) => sheets.firstWhere((s) => s.id.value == id);
  const lea = StudentId('lea');
  const tom = StudentId('tom');
  ExerciseRef ref(String block, int n) =>
      ExerciseRef(blockId: block, number: n);

  test('the first session has no recall exercise', () {
    expect(
      chooseRecallExercise(
        sheet: sheet('posture-1'),
        all: sheets,
        audience: Audience.children,
        validatedByStudent: const {},
      ),
      isNull,
    );
  });

  test('without students it is the last exercise of the previous session', () {
    final chosen = chooseRecallExercise(
      sheet: sheet('quart-1'),
      all: sheets,
      audience: Audience.children,
      validatedByStudent: const {},
    )!;

    expect(chosen.origin.id.value, 'demi-bille-2');
    expect(chosen.exercise.ref, ref('demi-bille', 4));
    expect(chosen.pending, 0);
    expect(chosen.students, 0);
  });

  test('prefers the exercise the most students have not validated', () {
    final chosen = chooseRecallExercise(
      sheet: sheet('quart-1'),
      all: sheets,
      audience: Audience.children,
      validatedByStudent: {
        // Léa a tout validé sauf posture 1 ; Tom a validé demi-bille 3 et 4
        // et posture 2 : posture 1 manque aux deux.
        lea: {ref('demi-bille', 1), ref('demi-bille', 2)}
          ..addAll({ref('demi-bille', 3), ref('demi-bille', 4)})
          ..add(ref('posture', 2)),
        tom: {ref('demi-bille', 3), ref('demi-bille', 4), ref('posture', 2)},
      },
    )!;

    expect(chosen.origin.id.value, 'posture-1');
    expect(chosen.exercise.ref, ref('posture', 1));
    expect(chosen.pending, 2);
    expect(chosen.students, 2);
  });

  test('breaks a tie by the most recent exercise', () {
    final chosen = chooseRecallExercise(
      sheet: sheet('quart-1'),
      all: sheets,
      audience: Audience.children,
      validatedByStudent: {
        lea: {ref('demi-bille', 4), ref('posture', 2)},
      },
    )!;

    // demi-bille 3 et posture 1 manquent tous deux : le plus récent gagne.
    expect(chosen.exercise.ref, ref('demi-bille', 3));
    expect(chosen.pending, 1);
  });

  test('falls back on the last exercise when everything is validated', () {
    final chosen = chooseRecallExercise(
      sheet: sheet('demi-bille-2'),
      all: sheets,
      audience: Audience.children,
      validatedByStudent: {
        lea: {
          ref('posture', 1),
          ref('posture', 2),
          ref('demi-bille', 1),
          ref('demi-bille', 2),
        },
      },
    )!;

    expect(chosen.origin.id.value, 'demi-bille-1');
    expect(chosen.exercise.ref, ref('demi-bille', 2));
    expect(chosen.pending, 0);
    expect(chosen.students, 1);
  });

  test('never picks an exercise of the session itself or of a later one', () {
    final chosen = chooseRecallExercise(
      sheet: sheet('demi-bille-1'),
      all: sheets,
      audience: Audience.children,
      validatedByStudent: {lea: const {}},
    )!;

    expect(chosen.origin.id.value, 'posture-1');
    expect(chosen.exercise.ref, ref('posture', 2));
  });

  test('ignores exercises not shown for the audience of the guide', () {
    // demi-bille 4 (dernier de la séance précédente) est réservé aux adultes.
    final restricted = [
      for (final s in sheets)
        if (s.id.value == 'demi-bille-2')
          s.copyWith(
            exercises: [
              for (final e in s.exercises)
                if (e.ref == ref('demi-bille', 4))
                  e.copyWith(weight: AudienceWeight(adults: 1))
                else
                  e,
            ],
          )
        else
          s,
    ];
    final target = restricted.firstWhere((s) => s.id.value == 'quart-1');

    final forChildren = chooseRecallExercise(
      sheet: target,
      all: restricted,
      audience: Audience.children,
      validatedByStudent: const {},
    )!;
    final forAdults = chooseRecallExercise(
      sheet: target,
      all: restricted,
      audience: Audience.adults,
      validatedByStudent: const {},
    )!;

    expect(forChildren.exercise.ref, ref('demi-bille', 3));
    expect(forAdults.exercise.ref, ref('demi-bille', 4));
  });
}
