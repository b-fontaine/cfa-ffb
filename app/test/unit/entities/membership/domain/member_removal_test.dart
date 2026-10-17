import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/entities/membership/domain/member_removal.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

Member _member(String id, Role role) =>
    Member(uid: UserId(id), role: role, displayName: id);

bool _can(Role viewer, String viewerId, Member member) => canRemoveMember(
  viewerRole: viewer,
  viewerId: UserId(viewerId),
  member: member,
);

void main() {
  group('canRemoveMember', () {
    test('a director removes a teacher, a student or a guardian', () {
      for (final role in [Role.teacher, Role.student, Role.guardian]) {
        expect(_can(Role.director, 'u-dir', _member('u-x', role)), isTrue);
      }
    });

    test('a director removes neither a director nor an administrator', () {
      expect(
        _can(Role.director, 'u-dir', _member('u-d2', Role.director)),
        isFalse,
      );
      expect(_can(Role.director, 'u-dir', _member('u-a', Role.admin)), isFalse);
    });

    test('nobody removes themselves', () {
      expect(
        _can(Role.director, 'u-dir', _member('u-dir', Role.director)),
        isFalse,
      );
      expect(
        _can(Role.admin, 'u-root', _member('u-root', Role.teacher)),
        isFalse,
      );
    });

    test('an administrator removes a director other than themselves', () {
      expect(
        _can(Role.admin, 'u-root', _member('u-d2', Role.director)),
        isTrue,
      );
    });

    test('a role without the club management capability removes nobody', () {
      for (final viewer in [Role.teacher, Role.student, Role.guardian]) {
        expect(_can(viewer, 'u-v', _member('u-x', Role.student)), isFalse);
      }
    });
  });
}
