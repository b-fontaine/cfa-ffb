import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/features/manage_club/domain/issue_invitation.dart';
import 'package:billard_cfa/features/manage_club/domain/list_issued_invitations.dart';
import 'package:billard_cfa/features/manage_club/domain/list_members.dart';
import 'package:billard_cfa/features/manage_club/domain/remove_member.dart';
import 'package:billard_cfa/features/manage_club/domain/rename_club.dart';
import 'package:billard_cfa/features/manage_club/domain/revoke_invitation.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/club_cubit.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/club_state.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_world.dart';
import '../../../../support/domain_world.dart';

void main() {
  late ClubWorld world;

  ClubCubit cubit() {
    final issued = IssuedInvitations(world.log, world.invitations, world.clock);
    return ClubCubit(
      ListMembers(world.members, world.scope, world.scope),
      ListIssuedInvitations(issued, world.scope, world.scope),
      RemoveMember(world.members, world.scope, world.scope),
      RevokeInvitation(issued, world.scope, world.scope),
      RenameClub(world.clubs, world.scope, world.scope),
      world.scope,
      world.scope,
    );
  }

  Future<Invitation> invite() async {
    final issued = IssuedInvitations(world.log, world.invitations, world.clock);
    final result = await IssueInvitation(
      world.invitations,
      world.directory,
      world.codes,
      issued,
      world.local.students,
      world.local.groups,
      world.local.seasons,
      world.clock,
      world.scope,
      world.scope,
    )(role: Role.teacher);
    final invitation = ok(result);
    return invitation;
  }

  setUp(() async {
    world = ClubWorld();
    await world.seedLocalClub();
    world
      ..seedMember('u-director', Role.director, name: 'Directrice')
      ..seedMember('u-sophie', Role.teacher, name: 'sophie', groups: ['g1']);
  });

  test('a director starts loading with the right to manage', () {
    world.signIn(Role.director);
    final c = cubit();
    expect(c.state.status, ClubStatus.loading);
    expect(c.state.canManage, isTrue);
  });

  test('a teacher cannot manage the club', () {
    world.signIn(
      Role.teacher,
      user: const UserId('u-sophie'),
      groupIds: [const GroupId('g1')],
    );
    expect(cubit().state.canManage, isFalse);
  });

  test('loads the members and the invitations of the device', () async {
    world.signIn(Role.director);
    final sent = await invite();
    final c = cubit();

    await c.load();

    expect(c.state.status, ClubStatus.ready);
    expect(
      [for (final m in c.state.members) m.displayName],
      ['Directrice', 'sophie'],
    );
    expect([for (final i in c.state.invitations) i.entry.code], [sent.code]);
    expect(c.state.failure, isNull);
    await c.close();
  });

  test('a teacher loads the invitations only, never the members', () async {
    world.signIn(
      Role.teacher,
      user: const UserId('u-sophie'),
      groupIds: [const GroupId('g1')],
    );
    final c = cubit();
    final reads = world.store.reads;

    await c.load();

    expect(c.state.status, ClubStatus.ready);
    expect(c.state.members, isEmpty);
    expect(
      world.store.reads,
      reads,
      reason: 'aucune invitation retenue : rien à relire',
    );
    await c.close();
  });

  test('a failing service is reported and the lists stay', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    world.store.failing = StoreFailureCode.unavailable;

    await c.load();

    expect(c.state.status, ClubStatus.failed);
    expect(c.state.failure, isA<ServiceFailure>());
    expect(
      c.state.members,
      hasLength(2),
      reason: 'la liste déjà chargée reste',
    );
    await c.close();
  });

  test('says which members the viewer may remove, never themselves', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();

    final removable = [
      for (final m in c.state.members)
        if (c.state.removable(m)) m.displayName,
    ];
    expect(removable, ['sophie']);
    await c.close();
  });

  test(
    'an administrator may remove a director other than themselves',
    () async {
      world
        ..seedMember('u-dir-b', Role.director, name: 'Autre directeur')
        ..signIn(Role.admin, user: const UserId('u-root'), isAdmin: true);
      final c = cubit();
      await c.load();

      expect(c.state.members.where(c.state.removable), hasLength(3));
      await c.close();
    },
  );

  test('removing a member reloads the list', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();

    await c.removeMember(c.state.members.last);

    expect([for (final m in c.state.members) m.displayName], ['Directrice']);
    expect(world.doc('clubs/c1/members/u-sophie'), isNull);
    await c.close();
  });

  test('a refused removal keeps the list and shows the failure', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();

    await c.removeMember(c.state.members.first);

    expect(c.state.members, hasLength(2));
    expect(
      (c.state.failure! as InvariantViolation).code,
      InvariantCode.actionNotAllowed,
    );
    await c.close();
  });

  test('revoking an invitation reloads the list', () async {
    world.signIn(Role.director);
    final sent = await invite();
    final c = cubit();
    await c.load();

    await c.revoke(sent.code);

    expect(c.state.invitations, isEmpty);
    expect(world.doc('invitations/${sent.code.value}'), isNull);
    await c.close();
  });

  test(
    'a failed revocation keeps the invitation and shows the failure',
    () async {
      world.signIn(Role.director);
      final sent = await invite();
      final c = cubit();
      await c.load();
      world.store.failing = StoreFailureCode.permissionDenied;

      await c.revoke(sent.code);

      expect(c.state.invitations, hasLength(1));
      expect(c.state.failure, isA<ServiceFailure>());
      await c.close();
    },
  );

  test('renaming returns true and clears an older failure', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    expect(await c.rename(' '), isFalse);
    expect(
      (c.state.failure! as InvariantViolation).code,
      InvariantCode.nameRequired,
    );

    expect(await c.rename('Club Lyon'), isTrue);

    expect(c.state.failure, isNull);
    expect(world.doc('clubs/c1')!['name'], 'Club Lyon');
    await c.close();
  });

  test('nothing is emitted once the cubit is closed', () async {
    world.signIn(Role.director);
    final c = cubit();
    final states = <ClubState>[];
    c.stream.listen(states.add);

    final loading = c.load();
    await c.close();
    await loading;

    expect(states, isEmpty);
  });
}
