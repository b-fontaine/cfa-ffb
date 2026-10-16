import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

const _lea = StudentId('lea');
const _theo = StudentId('theo');

Group empty({Audience audience = Audience.children, String name = 'Jeunes'}) =>
    Group(
      id: const GroupId('g'),
      seasonId: const SeasonId('s'),
      name: name,
      audience: audience,
    );

void main() {
  test('refuses a blank name', () {
    expect(() => empty(name: ' '), violation(InvariantCode.blankName));
  });

  test('starts without members', () {
    expect(empty().memberships, isEmpty);
    expect(empty().isMemberOn(_lea, day(5)), isFalse);
  });

  group('admit', () {
    test('opens a membership for a student of the group audience', () {
      final group = empty().admit(
        studentId: _lea,
        studentAudience: Audience.children,
        from: day(5),
      );

      expect(group.memberships.single.to, isNull);
      expect(group.isMemberOn(_lea, day(5)), isTrue);
    });

    test('refuses a student whose audience differs from the group', () {
      expect(
        () => empty().admit(
          studentId: _lea,
          studentAudience: Audience.adults,
          from: day(5),
        ),
        violation(InvariantCode.audienceMismatch),
      );
    });

    test('refuses a second open membership for the same student', () {
      final group = empty().admit(
        studentId: _lea,
        studentAudience: Audience.children,
        from: day(5),
      );

      expect(
        () => group.admit(
          studentId: _lea,
          studentAudience: Audience.children,
          from: day(8),
        ),
        violation(InvariantCode.membershipAlreadyOpen),
      );
    });

    test('allows several different students', () {
      final group = empty()
          .admit(
            studentId: _lea,
            studentAudience: Audience.children,
            from: day(5),
          )
          .admit(
            studentId: _theo,
            studentAudience: Audience.children,
            from: day(5),
          );

      expect(group.memberships, hasLength(2));
    });
  });

  group('isMemberOn', () {
    final group = empty()
        .admit(
          studentId: _lea,
          studentAudience: Audience.children,
          from: day(5),
        )
        .release(studentId: _lea, to: day(10));

    test('is false the day before the membership', () {
      expect(group.isMemberOn(_lea, day(4)), isFalse);
    });

    test('is true on the first and on the last day', () {
      expect(group.isMemberOn(_lea, day(5)), isTrue);
      expect(group.isMemberOn(_lea, day(10)), isTrue);
    });

    test('is false the day after the end', () {
      expect(group.isMemberOn(_lea, day(11)), isFalse);
    });

    test('is false for another student', () {
      expect(group.isMemberOn(_theo, day(7)), isFalse);
    });
  });

  group('release', () {
    final group = empty().admit(
      studentId: _lea,
      studentAudience: Audience.children,
      from: day(5),
    );

    test('closes the open membership and keeps the other ones', () {
      final other = group.admit(
        studentId: _theo,
        studentAudience: Audience.children,
        from: day(5),
      );

      final released = other.release(studentId: _lea, to: day(9));

      expect(released.memberships.first.to, day(9));
      expect(released.memberships.last.to, isNull);
    });

    test('accepts a closing date equal to the opening date', () {
      expect(
        group.release(studentId: _lea, to: day(5)).memberships.single.to,
        day(5),
      );
    });

    test('refuses a closing date before the opening date', () {
      expect(
        () => group.release(studentId: _lea, to: day(4)),
        violation(InvariantCode.membershipPeriodInvalid),
      );
    });

    test('refuses a student without open membership', () {
      expect(
        () => group.release(studentId: _theo, to: day(9)),
        violation(InvariantCode.membershipNotOpen),
      );
    });

    test('allows re-admission after a release', () {
      final again = group
          .release(studentId: _lea, to: day(9))
          .admit(
            studentId: _lea,
            studentAudience: Audience.children,
            from: day(12),
          );

      expect(again.isMemberOn(_lea, day(10)), isFalse);
      expect(again.isMemberOn(_lea, day(12)), isTrue);
    });
  });

  group('membersOn', () {
    Group group() => empty()
        .admit(
          studentId: _lea,
          studentAudience: Audience.children,
          from: day(5),
        )
        .admit(
          studentId: _theo,
          studentAudience: Audience.children,
          from: day(5),
        )
        .release(studentId: _theo, to: day(9))
        .admit(
          studentId: _theo,
          studentAudience: Audience.children,
          from: day(12),
        );

    test('lists each current member once, bounds included', () {
      expect(group().membersOn(day(5)), [_lea, _theo]);
      expect(group().membersOn(day(9)), [_lea, _theo]);
      expect(group().membersOn(day(12)), [_lea, _theo]);
    });

    test('leaves out a member outside of the membership period', () {
      expect(group().membersOn(day(4)), isEmpty);
      expect(group().membersOn(day(10)), [_lea]);
    });
  });
}
