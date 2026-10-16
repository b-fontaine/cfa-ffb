import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

AudienceArchive _audience({
  Audience audience = Audience.children,
  int sessions = 2,
  int presences = 5,
  int possible = 6,
  int students = 3,
  int attempts = 4,
}) => AudienceArchive(
  audience: audience,
  sessionCount: sessions,
  presenceCount: presences,
  possiblePresenceCount: possible,
  studentCount: students,
  attemptCount: attempts,
);

ExerciseArchive _exercise({
  int students = minCohortForFigures,
  int attempts = 4,
  int potted = 6,
  int total = 20,
}) => ExerciseArchive(
  audience: Audience.children,
  exercise: ref('a', 1),
  studentCount: students,
  attemptCount: attempts,
  potted: potted,
  total: total,
);

void main() {
  test('the figure threshold is three distinct students', () {
    expect(minCohortForFigures, 3);
  });

  group('AudienceArchive', () {
    test('accepts presences up to the possible presences', () {
      expect(_audience(presences: 6).presenceCount, 6);
    });

    test('refuses more presences than possible presences', () {
      expect(
        () => _audience(presences: 7),
        violation(InvariantCode.backupInvalid),
      );
    });

    test('refuses figures under the threshold of present students', () {
      for (final figures in <AudienceArchive Function()>[
        () => _audience(students: 2, presences: 1, possible: 1, attempts: 0),
        () => _audience(students: 2, presences: 0, possible: 1, attempts: 0),
        () => _audience(students: 2, presences: 0, possible: 0, attempts: 1),
      ]) {
        expect(figures, violation(InvariantCode.backupInvalid));
      }
    });

    test('accepts a block under the threshold that keeps only sessions', () {
      expect(
        _audience(
          students: 2,
          presences: 0,
          possible: 0,
          attempts: 0,
        ).sessionCount,
        2,
      );
    });

    test('refuses a negative count', () {
      expect(
        () => _audience(sessions: -1),
        violation(InvariantCode.backupInvalid),
      );
      expect(
        () => _audience(attempts: -1),
        violation(InvariantCode.backupInvalid),
      );
    });
  });

  group('ExerciseArchive', () {
    test('accepts exactly the threshold of distinct students', () {
      expect(_exercise().studentCount, 3);
    });

    test('refuses fewer distinct students than the threshold', () {
      expect(
        () => _exercise(students: 2),
        violation(InvariantCode.backupInvalid),
      );
    });

    test('refuses more balls potted than attempted', () {
      expect(
        () => _exercise(potted: 21),
        violation(InvariantCode.backupInvalid),
      );
    });
  });

  group('SeasonArchive', () {
    test('keeps a single block per audience and per exercise', () {
      final archive = SeasonArchive(
        seasonId: const SeasonId('s'),
        audiences: [_audience()],
        exercises: [_exercise()],
      );

      expect(archive.audienceOf(Audience.children)?.sessionCount, 2);
      expect(archive.audienceOf(Audience.adults), isNull);
    });

    test('refuses two blocks for the same audience', () {
      expect(
        () => SeasonArchive(
          seasonId: const SeasonId('s'),
          audiences: [_audience(), _audience()],
          exercises: const [],
        ),
        violation(InvariantCode.backupInconsistent),
      );
    });

    test('refuses two lines for the same exercise', () {
      expect(
        () => SeasonArchive(
          seasonId: const SeasonId('s'),
          audiences: const [],
          exercises: [_exercise(), _exercise()],
        ),
        violation(InvariantCode.backupInconsistent),
      );
    });

    test('carries no student identifier in its text form', () {
      final archive = SeasonArchive(
        seasonId: const SeasonId('s'),
        audiences: [_audience()],
        exercises: [_exercise()],
      );

      expect(archive.toString(), isNot(contains('studentId')));
      expect(archive.toString(), isNot(contains('Léa')));
    });
  });
}
