import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/features/administration/domain/create_club.dart';
import 'package:billard_cfa/features/administration/domain/invite_director.dart';
import 'package:billard_cfa/features/administration/domain/list_clubs.dart';
import 'package:billard_cfa/features/administration/domain/list_director_invitations.dart';
import 'package:billard_cfa/features/administration/domain/revoke_director_invitation.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_cubit.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_state.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_world.dart';

void main() {
  late ClubWorld world;
  late AdministrationCubit cubit;
  const root = UserId('u-root');

  AdministrationCubit build() {
    final issued = IssuedInvitations(world.log, world.invitations, world.clock);
    return AdministrationCubit(
      ListClubs(world.clubs, world.scope),
      CreateClub(world.clubs, world.local.ids, world.scope),
      InviteDirector(
        world.clubs,
        world.invitations,
        world.codes,
        issued,
        world.clock,
        world.scope,
      ),
      ListDirectorInvitations(issued, world.scope),
      RevokeDirectorInvitation(issued, world.scope),
    );
  }

  setUp(() {
    world = ClubWorld();
    world.scope.signIn(root, isAdmin: true);
    cubit = build();
  });

  tearDown(() => cubit.close());

  test('starts loading', () {
    expect(cubit.state.status, AdministrationStatus.loading);
  });

  test('an empty platform has no club', () async {
    await cubit.load();
    expect(cubit.state.status, AdministrationStatus.ready);
    expect(cubit.state.clubs, isEmpty);
  });

  test('creating a club adds it to the list', () async {
    expect(await cubit.createClub('Club Nice'), isTrue);

    expect([for (final c in cubit.state.clubs) c.club.name], ['Club Nice']);
    expect(cubit.state.failure, isNull);
  });

  test('a refused name shows the failure, a good one clears it', () async {
    await cubit.createClub('Alpha');

    expect(await cubit.createClub(' '), isFalse);

    expect(
      (cubit.state.failure! as InvariantViolation).code,
      InvariantCode.nameRequired,
    );
    expect(cubit.state.clubs, hasLength(1));
    expect(await cubit.createClub('Beta'), isTrue);
    expect(cubit.state.failure, isNull);
  });

  test('inviting a director shows the code and lists the invitation', () async {
    await cubit.createClub('Club Nice');
    final club = cubit.state.clubs.single.club;

    await cubit.inviteDirector(club.id);

    expect(cubit.state.issued, isNotNull);
    expect(cubit.state.issued!.clubId, club.id);
    expect(cubit.state.clubs.single.invitations, hasLength(1));
    expect(
      cubit.state.clubs.single.invitations.single.entry.code,
      cubit.state.issued!.code,
    );
  });

  test('dismissing hides the code but keeps the invitation', () async {
    await cubit.createClub('Club Nice');
    await cubit.inviteDirector(cubit.state.clubs.single.club.id);

    cubit.dismissIssued();

    expect(cubit.state.issued, isNull);
    expect(cubit.state.clubs.single.invitations, hasLength(1));
  });

  test('revoking removes the invitation and hides its code if shown', () async {
    await cubit.createClub('Club Nice');
    final club = cubit.state.clubs.single.club;
    await cubit.inviteDirector(club.id);
    final code = cubit.state.issued!.code;

    await cubit.revoke(club.id, code);

    expect(cubit.state.issued, isNull);
    expect(cubit.state.clubs.single.invitations, isEmpty);
    expect(world.doc('invitations/${code.value}'), isNull);
  });

  test('revoking another code keeps the code shown', () async {
    await cubit.createClub('Club Nice');
    final club = cubit.state.clubs.single.club;
    await cubit.inviteDirector(club.id);
    final first = cubit.state.issued!.code;
    await cubit.inviteDirector(club.id);
    final second = cubit.state.issued!.code;

    await cubit.revoke(club.id, first);

    expect(cubit.state.issued!.code, second);
    expect(cubit.state.clubs.single.invitations, hasLength(1));
  });

  test(
    'an unreachable service fails the load and an action keeps the list',
    () async {
      world.store.failing = StoreFailureCode.unavailable;
      await cubit.load();
      expect(cubit.state.status, AdministrationStatus.failed);
      expect(cubit.state.failure, isA<ServiceFailure>());

      world.store.failing = null;
      await cubit.createClub('Club Nice');
      final club = cubit.state.clubs.single.club;
      world.store.failing = StoreFailureCode.permissionDenied;

      await cubit.inviteDirector(club.id);
      expect(cubit.state.failure, isA<ServiceFailure>());
      expect(cubit.state.issued, isNull);

      await cubit.revoke(club.id, world.codes.next());
      expect(cubit.state.failure, isA<ServiceFailure>());
      expect(cubit.state.clubs, hasLength(1));
    },
  );

  test('a member of a club is refused everything', () async {
    world.signIn(Role.director);
    await cubit.load();
    expect(cubit.state.status, AdministrationStatus.failed);
    expect(
      (cubit.state.failure! as InvariantViolation).code,
      InvariantCode.actionNotAllowed,
    );
  });

  test('nothing is emitted once the cubit is closed', () async {
    final loading = cubit.load();
    await cubit.close();
    await loading;
    expect(cubit.state.status, AdministrationStatus.loading);
  });
}
