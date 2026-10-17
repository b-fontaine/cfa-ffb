import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/features/manage_club/domain/list_members.dart';
import 'package:billard_cfa/features/manage_club/domain/remove_member.dart';
import 'package:billard_cfa/features/manage_club/domain/rename_club.dart';
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

  setUp(() {
    world = ClubWorld()
      ..seedMember('u-director', Role.director, name: 'Directrice')
      ..seedMember('u-sophie', Role.teacher, name: 'sophie', groups: ['g1'])
      ..seedMember('u-lea', Role.student, name: 'Léa', students: ['s1'])
      ..seedMember('u-anne', Role.guardian, name: 'Anne', students: ['s1']);
  });

  group('ListMembers', () {
    test(
      'the director reads the members of the club, sorted by name',
      () async {
        world.signIn(Role.director);
        final members = ok(
          await ListMembers(world.members, world.scope, world.scope)(),
        );
        expect(
          [for (final m in members) m.displayName],
          ['Anne', 'Directrice', 'Léa', 'sophie'],
        );
        expect(members.last.role, Role.teacher);
        expect(members.last.groupIds, [const GroupId('g1')]);
      },
    );

    test('the administrator acting in the club reads them too', () async {
      world.signIn(Role.admin, user: const UserId('u-root'), isAdmin: true);
      final members = ok(
        await ListMembers(world.members, world.scope, world.scope)(),
      );
      expect(members, hasLength(4));
    });

    test('a teacher, a student and a parent are refused', () async {
      for (final role in [Role.teacher, Role.student, Role.guardian]) {
        world.signIn(role, user: const UserId('u-sophie'));
        final result = await ListMembers(
          world.members,
          world.scope,
          world.scope,
        )();
        expect(
          codeOf(result),
          InvariantCode.actionNotAllowed,
          reason: role.name,
        );
      }
    });

    test('nobody signed in is refused', () async {
      expect(
        codeOf(await ListMembers(world.members, world.scope, world.scope)()),
        InvariantCode.actionNotAllowed,
      );
    });

    test('an unreadable service is reported, not crashed', () async {
      world
        ..signIn(Role.director)
        ..store.failing = StoreFailureCode.unavailable;
      final result = await ListMembers(
        world.members,
        world.scope,
        world.scope,
      )();
      expect(err(result), isA<ServiceFailure>());
      expect(
        (err(result) as ServiceFailure).code,
        ServiceFailureCode.unavailable,
      );
    });
  });

  group('RemoveMember', () {
    RemoveMember remove() =>
        RemoveMember(world.members, world.scope, world.scope);

    Member member(String uid, Role role) =>
        Member(uid: UserId(uid), role: role, displayName: uid);

    test('the director removes a teacher, a student or a parent', () async {
      world.signIn(Role.director);
      for (final (uid, role) in [
        ('u-sophie', Role.teacher),
        ('u-lea', Role.student),
        ('u-anne', Role.guardian),
      ]) {
        ok(await remove()(member(uid, role)));
        expect(world.doc('clubs/c1/members/$uid'), isNull, reason: uid);
      }
      expect(world.doc('clubs/c1/members/u-director'), isNotNull);
    });

    test('the director cannot remove a director nor themselves', () async {
      world
        ..seedMember('u-dir-b', Role.director)
        ..signIn(Role.director);
      expect(
        codeOf(await remove()(member('u-dir-b', Role.director))),
        InvariantCode.actionNotAllowed,
      );
      expect(
        codeOf(await remove()(member('u-director', Role.teacher))),
        InvariantCode.actionNotAllowed,
        reason: 'pas soi-même',
      );
      expect(world.doc('clubs/c1/members/u-dir-b'), isNotNull);
    });

    test('the administrator removes a director', () async {
      world
        ..seedMember('u-dir-b', Role.director)
        ..signIn(Role.admin, user: const UserId('u-root'), isAdmin: true);
      ok(await remove()(member('u-dir-b', Role.director)));
      expect(world.doc('clubs/c1/members/u-dir-b'), isNull);
    });

    test('a teacher cannot remove anybody', () async {
      world.signIn(Role.teacher, user: const UserId('u-sophie'));
      expect(
        codeOf(await remove()(member('u-lea', Role.student))),
        InvariantCode.actionNotAllowed,
      );
      expect(world.doc('clubs/c1/members/u-lea'), isNotNull);
    });
  });

  group('RenameClub', () {
    RenameClub rename() => RenameClub(world.clubs, world.scope, world.scope);

    test('the director renames the club, trimming the name', () async {
      world.signIn(Role.director);
      ok(await rename()('  Club Lyon '));
      expect(world.doc('clubs/c1')!['name'], 'Club Lyon');
    });

    test('a blank name is refused and nothing is written', () async {
      world.signIn(Role.director);
      expect(codeOf(await rename()('   ')), InvariantCode.nameRequired);
      expect(world.doc('clubs/c1')!['name'], 'Club un');
    });

    test('the name is limited to the length the server accepts', () async {
      world.signIn(Role.director);
      ok(await rename()('é' * maxClubNameLength));
      expect(
        codeOf(await rename()('é' * (maxClubNameLength + 1))),
        InvariantCode.nameTooLong,
      );
      expect(world.doc('clubs/c1')!['name'], 'é' * maxClubNameLength);
    });

    test('a teacher cannot rename the club', () async {
      world.signIn(Role.teacher, user: const UserId('u-sophie'));
      expect(codeOf(await rename()('Autre')), InvariantCode.actionNotAllowed);
      expect(world.doc('clubs/c1')!['name'], 'Club un');
    });
  });
}
