import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_failure.dart';
import 'package:billard_cfa/features/sign_in/data/key_value_pending_invitations.dart';
import 'package:billard_cfa/features/sign_in/domain/accept_invitation.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_world.dart';

void main() {
  late ClubWorld world;
  late KeyValuePendingInvitations pending;
  late AcceptInvitation accept;
  final code = InvitationCode.tryParse('GUARDIANCODE')!;
  const user = UserId('u-anne');

  setUp(() async {
    world = ClubWorld();
    pending = KeyValuePendingInvitations(world.keyValues);
    accept = AcceptInvitation(world.invitations, pending, world.scope);
    world.seedMember('u-director', Role.director);
    await world.invitations.create(
      Invitation(
        code: code,
        clubId: ClubWorld.club,
        role: Role.guardian,
        createdBy: ClubWorld.director,
        createdAt: world.clock.now(),
        expiresAt: world.clock.now().add(const Duration(days: 7)),
        groupIds: const [GroupId('g1')],
        studentIds: const [StudentId('s1')],
      ),
    );
    world.scope.signIn(user);
    await pending.hold(user, code);
  });

  test(
    'joins the club, consumes the invitation and forgets the kept code',
    () async {
      await accept(code: 'GUARDIANCODE', displayName: ' Anne ');

      final member = world.doc('clubs/c1/members/u-anne')!;
      expect(member['role'], 'guardian');
      expect(member['displayName'], 'Anne');
      expect(member['studentIds'], ['s1']);
      expect(world.doc('invitations/GUARDIANCODE')!['used'], isTrue);
      expect(await pending.read(user), isNull);
    },
  );

  test('normalises what was typed', () async {
    await accept(code: 'guardian-code', displayName: 'Anne');
    expect(world.doc('clubs/c1/members/u-anne'), isNotNull);
  });

  test(
    'a code of the wrong shape is refused before anything is read',
    () async {
      final reads = world.store.reads;

      await expectLater(
        accept(code: 'court', displayName: 'Anne'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.invalidInvitationCode,
          ),
        ),
      );

      expect(world.store.reads, reads);
      expect(await pending.read(user), code);
    },
  );

  test('a refused invitation keeps the kept code for another try', () async {
    world.clock.advance(const Duration(days: 8));

    await expectLater(
      accept(code: 'GUARDIANCODE', displayName: 'Anne'),
      throwsA(
        isA<InvitationFailure>().having(
          (e) => e.code,
          'code',
          InvitationFailureCode.expired,
        ),
      ),
    );

    expect(await pending.read(user), code);
    expect(world.doc('clubs/c1/members/u-anne'), isNull);
  });

  test('a blank name keeps everything as it was', () async {
    await expectLater(
      accept(code: 'GUARDIANCODE', displayName: '  '),
      throwsA(
        isA<InvariantViolation>().having(
          (e) => e.code,
          'code',
          InvariantCode.nameRequired,
        ),
      ),
    );
    expect(world.doc('invitations/GUARDIANCODE')!['used'], isFalse);
    expect(await pending.read(user), code);
  });

  test('somebody who is not signed in cannot accept', () async {
    world.scope.signOut();

    await expectLater(
      accept(code: 'GUARDIANCODE', displayName: 'Anne'),
      throwsA(
        isA<InvariantViolation>().having(
          (e) => e.code,
          'code',
          InvariantCode.actionNotAllowed,
        ),
      ),
    );
  });

  test(
    'a code accepted for another code than the kept one clears the kept one',
    () async {
      await pending.hold(user, InvitationCode.tryParse('OTHEROTHERXY')!);

      await accept(code: 'GUARDIANCODE', displayName: 'Anne');

      expect(await pending.read(user), isNull);
    },
  );
}
