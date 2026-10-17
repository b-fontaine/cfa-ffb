import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/features/administration/domain/create_club.dart';
import 'package:billard_cfa/features/administration/domain/invite_director.dart';
import 'package:billard_cfa/features/administration/domain/list_clubs.dart';
import 'package:billard_cfa/features/administration/domain/list_director_invitations.dart';
import 'package:billard_cfa/features/administration/domain/revoke_director_invitation.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_world.dart';
import '../../../../support/domain_world.dart';

void main() {
  late ClubWorld world;
  const root = UserId('u-root');

  void admin() => world.scope.signIn(root, isAdmin: true);
  void director() => world.scope.signIn(ClubWorld.director);

  IssuedInvitations issued() =>
      IssuedInvitations(world.log, world.invitations, world.clock);

  setUp(() {
    world = ClubWorld();
    world
      ..seedMember('u-director', Role.director)
      ..store.seed('clubs/c2', {
        'name': 'Alpha',
        'createdAt': world.clock.now(),
      });
  });

  group('ListClubs', () {
    test('the administrator lists every club, sorted by name', () async {
      admin();
      final clubs = ok(await ListClubs(world.clubs, world.scope)());
      expect([for (final c in clubs) c.name], ['Alpha', 'Club un']);
    });

    test('anybody else is refused, signed in or not', () async {
      director();
      expect(
        codeOf(await ListClubs(world.clubs, world.scope)()),
        InvariantCode.actionNotAllowed,
      );
      world.scope.signOut();
      expect(
        codeOf(await ListClubs(world.clubs, world.scope)()),
        InvariantCode.actionNotAllowed,
      );
    });

    test('an unreachable service is reported', () async {
      admin();
      world.store.failing = StoreFailureCode.unavailable;
      expect(
        err(await ListClubs(world.clubs, world.scope)()),
        isA<ServiceFailure>(),
      );
    });
  });

  group('CreateClub', () {
    CreateClub create() =>
        CreateClub(world.clubs, world.local.ids, world.scope);

    test('creates a club with a fresh identifier and trims the name', () async {
      admin();

      final club = ok(await create()('  Club Nice '));

      expect(club.name, 'Club Nice');
      expect(club.id, const ClubId('id-1'));
      expect(world.doc('clubs/id-1')!['name'], 'Club Nice');
      expect(world.doc('clubs/id-1')!.keys, containsAll(['name', 'createdAt']));
    });

    test('two clubs get two identifiers', () async {
      admin();
      final first = ok(await create()('A'));
      final second = ok(await create()('B'));
      expect(first.id, isNot(second.id));
    });

    test(
      'refuses a blank name and a name over the limit, writing nothing',
      () async {
        admin();
        expect(codeOf(await create()('  ')), InvariantCode.nameRequired);
        expect(
          codeOf(await create()('é' * (maxClubNameLength + 1))),
          InvariantCode.nameTooLong,
        );
        expect(
          world.store.documents.keys.where((p) => p.startsWith('clubs/id-')),
          isEmpty,
        );
      },
    );

    test('only the administrator creates clubs', () async {
      director();
      expect(codeOf(await create()('Pirate')), InvariantCode.actionNotAllowed);
    });
  });

  group('InviteDirector', () {
    InviteDirector invite() => InviteDirector(
      world.clubs,
      world.invitations,
      world.codes,
      issued(),
      world.clock,
      world.scope,
    );

    test(
      'creates a director invitation for 48 hours and remembers the code',
      () async {
        admin();

        final invitation = ok(await invite()(const ClubId('c2')));

        expect(invitation.role, Role.director);
        expect(invitation.clubId, const ClubId('c2'));
        expect(invitation.createdBy, root);
        expect(invitation.expiresAt, DateTime(2026, 10, 14, 9, 30));
        expect(invitation.groupIds, isEmpty);
        final stored = world.doc('invitations/${invitation.code.value}')!;
        expect(stored['role'], 'director');
        expect(stored['clubId'], 'c2');
        final entries = await world.log.read(root, const ClubId('c2'));
        expect([for (final e in entries) e.code], [invitation.code]);
      },
    );

    test('refuses an unknown club', () async {
      admin();
      expect(err(await invite()(const ClubId('nope'))), isA<NotFound>());
      expect(
        world.store.documents.keys.where((p) => p.startsWith('invitations')),
        isEmpty,
      );
    });

    test('only the administrator invites a director', () async {
      director();
      expect(
        codeOf(await invite()(const ClubId('c2'))),
        InvariantCode.actionNotAllowed,
      );
    });
  });

  group('ListDirectorInvitations and RevokeDirectorInvitation', () {
    test(
      'lists then revokes the director invitations of this device',
      () async {
        admin();
        final invitation = ok(
          await InviteDirector(
            world.clubs,
            world.invitations,
            world.codes,
            issued(),
            world.clock,
            world.scope,
          )(const ClubId('c2')),
        );

        final listed = ok(
          await ListDirectorInvitations(issued(), world.scope)(
            const ClubId('c2'),
          ),
        );
        expect(listed.single.entry.code, invitation.code);
        expect(listed.single.status, InvitationStatus.waiting);

        ok(
          await RevokeDirectorInvitation(issued(), world.scope)(
            const ClubId('c2'),
            invitation.code,
          ),
        );

        expect(world.doc('invitations/${invitation.code.value}'), isNull);
        expect(
          ok(
            await ListDirectorInvitations(issued(), world.scope)(
              const ClubId('c2'),
            ),
          ),
          isEmpty,
        );
      },
    );

    test('only the administrator reads or revokes them', () async {
      director();
      expect(
        codeOf(
          await ListDirectorInvitations(issued(), world.scope)(
            const ClubId('c2'),
          ),
        ),
        InvariantCode.actionNotAllowed,
      );
      expect(
        codeOf(
          await RevokeDirectorInvitation(issued(), world.scope)(
            const ClubId('c2'),
            world.codes.next(),
          ),
        ),
        InvariantCode.actionNotAllowed,
      );
    });
  });
}
