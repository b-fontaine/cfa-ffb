import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

Student enrolled() => Student.enroll(
  id: const StudentId('s1'),
  firstName: 'Hugo',
  audience: Audience.children,
  since: day(1),
);

void main() {
  group('enrolment', () {
    test('starts with one history entry and the given audience', () {
      final student = enrolled();

      expect(student.currentAudience, Audience.children);
      expect(student.audienceHistory, hasLength(1));
      expect(student.audienceHistory.single.effectiveFrom, day(1));
    });

    test('refuses a blank first name', () {
      expect(
        () => Student.enroll(
          id: const StudentId('s'),
          firstName: '  ',
          audience: Audience.children,
          since: day(1),
        ),
        violation(InvariantCode.blankName),
      );
    });

    test('refuses an empty history', () {
      expect(
        () => Student(
          id: const StudentId('s'),
          firstName: 'Léa',
          audienceHistory: const [],
        ),
        violation(InvariantCode.emptyAudienceHistory),
      );
    });

    test('refuses an unordered history', () {
      expect(
        () => Student(
          id: const StudentId('s'),
          firstName: 'Léa',
          audienceHistory: [
            AudienceChange(audience: Audience.children, effectiveFrom: day(5)),
            AudienceChange(audience: Audience.adults, effectiveFrom: day(5)),
          ],
        ),
        violation(InvariantCode.audienceChangeNotChronological),
      );
    });
  });

  group('R7 manual audience change', () {
    test('appends an entry and keeps the past untouched', () {
      final before = enrolled();

      final after = before.changeAudience(Audience.adults, day(10));

      expect(after.currentAudience, Audience.adults);
      expect(after.audienceHistory.map((c) => c.audience), [
        Audience.children,
        Audience.adults,
      ]);
      expect(after.audienceHistory.first, before.audienceHistory.first);
      expect(before.currentAudience, Audience.children);
    });

    test('allows going back to children later', () {
      final student = enrolled()
          .changeAudience(Audience.adults, day(10))
          .changeAudience(Audience.children, day(20));

      expect(student.audienceHistory, hasLength(3));
      expect(student.currentAudience, Audience.children);
    });

    test('refuses the audience already followed', () {
      expect(
        () => enrolled().changeAudience(Audience.children, day(10)),
        violation(InvariantCode.audienceUnchanged),
      );
    });

    test('refuses a change on the same day as the previous one', () {
      expect(
        () => enrolled().changeAudience(Audience.adults, day(1)),
        violation(InvariantCode.audienceChangeNotChronological),
      );
    });

    test('refuses a change before the previous one', () {
      expect(
        () => enrolled().changeAudience(
          Audience.adults,
          day(1).subtract(const Duration(days: 1)),
        ),
        violation(InvariantCode.audienceChangeNotChronological),
      );
    });

    test('accepts a change the day after', () {
      expect(
        enrolled().changeAudience(Audience.adults, day(2)).currentAudience,
        Audience.adults,
      );
    });
  });

  group('audienceAt', () {
    final student = enrolled().changeAudience(Audience.adults, day(10));

    test('is null before the enrolment', () {
      expect(
        student.audienceAt(day(1).subtract(const Duration(days: 1))),
        isNull,
      );
    });

    test('is the first audience on the enrolment day', () {
      expect(student.audienceAt(day(1)), Audience.children);
    });

    test('is still the first audience the day before the change', () {
      expect(student.audienceAt(day(9)), Audience.children);
    });

    test('is the new audience on the effective day', () {
      expect(student.audienceAt(day(10)), Audience.adults);
    });

    test('stays the new audience afterwards', () {
      expect(student.audienceAt(day(28)), Audience.adults);
    });
  });
}
