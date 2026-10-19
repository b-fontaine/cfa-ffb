import 'dart:async';

import 'package:billard_cfa/app/router.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/features/administration/domain/create_club.dart';
import 'package:billard_cfa/features/administration/domain/invite_director.dart';
import 'package:billard_cfa/features/administration/domain/list_clubs.dart';
import 'package:billard_cfa/features/administration/domain/list_director_invitations.dart';
import 'package:billard_cfa/features/administration/domain/revoke_director_invitation.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_cubit.dart';
import 'package:billard_cfa/features/manage_club/domain/issue_invitation.dart';
import 'package:billard_cfa/features/manage_club/domain/list_invitable_groups.dart';
import 'package:billard_cfa/features/manage_club/domain/list_invitable_students.dart';
import 'package:billard_cfa/features/manage_club/domain/list_issued_invitations.dart';
import 'package:billard_cfa/features/manage_club/domain/list_members.dart';
import 'package:billard_cfa/features/manage_club/domain/remove_member.dart';
import 'package:billard_cfa/features/manage_club/domain/rename_club.dart';
import 'package:billard_cfa/features/manage_club/domain/revoke_invitation.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/club_cubit.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_cubit.dart';
import 'package:billard_cfa/features/sign_in/data/key_value_pending_invitations.dart';
import 'package:billard_cfa/features/sign_in/domain/accept_invitation.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/join_cubit.dart';
import 'package:billard_cfa/pages/administration/presentation/administration_page.dart';
import 'package:billard_cfa/pages/club/presentation/club_page.dart';
import 'package:billard_cfa/pages/invite_member/presentation/invite_member_page.dart';
import 'package:billard_cfa/pages/join/presentation/join_page.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/club_world.dart';

void main() {
  late ClubWorld world;

  setUp(() async {
    world = ClubWorld();
    await world.seedLocalClub();
    world
      ..seedMember('u-director', Role.director, name: 'Directrice')
      ..seedMember('u-sophie', Role.teacher, name: 'sophie', groups: ['g1']);
  });

  IssuedInvitations issued() =>
      IssuedInvitations(world.log, world.invitations, world.clock);

  ClubCubit clubCubit({bool load = true}) {
    final cubit = ClubCubit(
      ListMembers(world.members, world.scope, world.scope),
      ListIssuedInvitations(issued(), world.scope, world.scope),
      RemoveMember(world.members, world.scope, world.scope),
      RevokeInvitation(issued(), world.scope, world.scope),
      RenameClub(world.clubs, world.scope, world.scope),
      world.scope,
      world.scope,
    );
    if (load) unawaited(cubit.load());
    return cubit;
  }

  InviteCubit inviteCubit({bool load = true}) {
    final cubit = InviteCubit(
      ListInvitableStudents(
        world.local.students,
        world.local.groups,
        world.local.seasons,
        world.clock,
        world.scope,
        world.scope,
      ),
      ListInvitableGroups(
        world.local.groups,
        world.local.seasons,
        world.clock,
        world.scope,
        world.scope,
      ),
      IssueInvitation(
        world.invitations,
        world.directory,
        world.codes,
        issued(),
        world.local.students,
        world.local.groups,
        world.local.seasons,
        world.clock,
        world.scope,
        world.scope,
      ),
      world.scope,
    );
    if (load) unawaited(cubit.load());
    return cubit;
  }

  AdministrationCubit adminCubit({bool load = true}) {
    final cubit = AdministrationCubit(
      ListClubs(world.clubs, world.scope),
      CreateClub(world.clubs, world.local.ids, world.scope),
      InviteDirector(
        world.clubs,
        world.invitations,
        world.codes,
        issued(),
        world.clock,
        world.scope,
      ),
      ListDirectorInvitations(issued(), world.scope),
      RevokeDirectorInvitation(issued(), world.scope),
    );
    if (load) unawaited(cubit.load());
    return cubit;
  }

  Future<void> pump<C extends Cubit<Object?>>(
    WidgetTester tester,
    C cubit,
    Widget page, {
    Locale locale = const Locale('en'),
  }) async {
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<C>.value(value: cubit, child: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ClubPage', () {
    Widget page({VoidCallback? onInvite, VoidCallback? onRenamed}) => ClubPage(
      clubName: 'Club un',
      onInvite: onInvite ?? () {},
      onBack: () {},
      onRenamed: onRenamed ?? () {},
    );

    testWidgets('a director sees the team, the invitations and the actions', (
      tester,
    ) async {
      world.signIn(Role.director);
      var invited = 0;
      await pump(tester, clubCubit(), page(onInvite: () => invited++));

      expect(find.text('Mon club'), findsNothing);
      expect(find.text('My club'), findsOneWidget);
      expect(find.text('Club un'), findsOneWidget);
      expect(find.text('Team and families'), findsOneWidget);
      expect(find.text('Directrice'), findsOneWidget);
      expect(find.text('sophie'), findsOneWidget);
      expect(find.text('Rename the club'), findsOneWidget);
      expect(find.text('Remove access'), findsOneWidget, reason: 'ni soi-même');
      expect(
        find.text('No invitation sent from this device yet.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Invite someone'));
      expect(invited, 1);
    });

    testWidgets('a teacher sees the invitations and the invite action only', (
      tester,
    ) async {
      world.signIn(
        Role.teacher,
        user: const UserId('u-sophie'),
        groupIds: [const GroupId('g1')],
      );
      await pump(tester, clubCubit(), page());

      expect(find.text('Invite someone'), findsOneWidget);
      expect(find.text('Team and families'), findsNothing);
      expect(find.text('Rename the club'), findsNothing);
      expect(find.text('Invitations sent from this device'), findsOneWidget);
    });

    testWidgets(
      'an administrator may remove a director other than themselves',
      (tester) async {
        world
          ..seedMember('u-dir-b', Role.director, name: 'Autre directeur')
          ..signIn(Role.admin, user: const UserId('u-root'), isAdmin: true);
        await pump(tester, clubCubit(), page());

        expect(find.text('Remove access'), findsNWidgets(3));
      },
    );

    testWidgets('renaming asks the new name and tells the page it changed', (
      tester,
    ) async {
      world.signIn(Role.director);
      var renamed = 0;
      await pump(tester, clubCubit(), page(onRenamed: () => renamed++));

      await tester.tap(find.text('Rename the club'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Club Lyon');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(renamed, 1);
      expect(world.doc('clubs/c1')!['name'], 'Club Lyon');
    });

    testWidgets(
      'cancelling the rename or a refused name does not tell the page',
      (tester) async {
        world.signIn(Role.director);
        var renamed = 0;
        await pump(tester, clubCubit(), page(onRenamed: () => renamed++));

        await tester.tap(find.text('Rename the club'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Rename the club'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(renamed, 0);
        expect(world.doc('clubs/c1')!['name'], 'Club un');
        expect(find.text('A name is required.'), findsOneWidget);
      },
    );

    testWidgets('a failure of the service is announced', (tester) async {
      world.signIn(Role.director);
      world.store.failing = StoreFailureCode.unavailable;
      await pump(tester, clubCubit(), page());

      expect(
        find.text(
          'The service is not responding. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('French titles', (tester) async {
      world.signIn(Role.director);
      await pump(tester, clubCubit(), page(), locale: const Locale('fr'));
      expect(find.text('Mon club'), findsOneWidget);
      expect(find.text('Équipe et familles'), findsOneWidget);
    });
  });

  group('InviteMemberPage', () {
    testWidgets('shows the form, then the code, then the form again', (
      tester,
    ) async {
      world.signIn(Role.director);
      await pump(
        tester,
        inviteCubit(),
        InviteMemberPage(
          onBack: () {},
          linkFor: inviteLinkFor('https://club.example'),
        ),
      );

      expect(find.text('Who do you invite?'), findsOneWidget);
      await tester.tap(find.text('Teacher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create the invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Invitation code'), findsOneWidget);
      expect(find.text('Copy the link'), findsOneWidget);
      expect(find.text('Who do you invite?'), findsNothing);

      await tester.tap(find.text('Invite someone else'));
      await tester.pumpAndSettle();
      expect(find.text('Who do you invite?'), findsOneWidget);
    });

    testWidgets('a role that cannot invite gets an error with a retry', (
      tester,
    ) async {
      world.signIn(Role.student, user: const UserId('u-x'));
      await pump(tester, inviteCubit(), InviteMemberPage(onBack: () {}));

      expect(
        find.text('Your role does not allow this action.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows a wait while loading', (tester) async {
      world.signIn(Role.director);
      final cubit = inviteCubit(load: false);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: InviteMemberPage(onBack: () {}),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('JoinPage', () {
    JoinCubit joinCubit() => JoinCubit(
      AcceptInvitation(
        world.invitations,
        KeyValuePendingInvitations(world.keyValues),
        world.scope,
      ),
    );

    testWidgets('has no back and no sign-out unless given', (tester) async {
      await pump(tester, joinCubit(), JoinPage(onJoined: () {}));

      expect(find.text('Join a club'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('offers the back and the sign-out it is given', (tester) async {
      var back = 0;
      var out = 0;
      await pump(
        tester,
        joinCubit(),
        JoinPage(onJoined: () {}, onBack: () => back++, onSignOut: () => out++),
      );

      await tester.tap(find.text('Back'));
      await tester.tap(find.text('Sign out'));

      expect([back, out], [1, 1]);
    });

    testWidgets('tells the page once the club is joined, and only then', (
      tester,
    ) async {
      world
        ..scope.signIn(const UserId('u-anne'))
        ..seedMember('u-director', Role.director);
      await world.local.seedClub();
      var joined = 0;
      await pump(
        tester,
        joinCubit(),
        JoinPage(initialCode: 'UNKNOWNCODEX', onJoined: () => joined++),
      );

      await tester.enterText(find.byType(TextField).at(1), 'Anne');
      await tester.tap(find.text('Join the club'));
      await tester.pumpAndSettle();
      expect(joined, 0);
      expect(
        find.text('This code does not exist. Check it and try again.'),
        findsOneWidget,
      );
    });
  });

  group('AdministrationPage', () {
    testWidgets('an empty platform invites to create the first club', (
      tester,
    ) async {
      world.store.documents.keys.toList().forEach(world.store.remove);
      world.scope.signIn(const UserId('u-root'), isAdmin: true);
      await pump(tester, adminCubit(), AdministrationPage(onBack: () {}));

      expect(find.text('No club yet.'), findsOneWidget);
      expect(find.text('Create a club'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('creates a club, then invites its director', (tester) async {
      world.store.documents.keys.toList().forEach(world.store.remove);
      world.scope.signIn(const UserId('u-root'), isAdmin: true);
      await pump(
        tester,
        adminCubit(),
        AdministrationPage(onBack: () {}, backLabel: 'Back to More'),
      );

      await tester.tap(find.text('Create a club'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Club Nice');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Club Nice'), findsOneWidget);
      expect(find.text('Back to More'), findsOneWidget);

      await tester.tap(find.text('Invite a director'));
      await tester.pumpAndSettle();
      expect(find.text('Invitation code'), findsOneWidget);
      expect(find.text('Director · Waiting'), findsOneWidget);
    });

    testWidgets('a refused name is announced and nothing is created', (
      tester,
    ) async {
      world.scope.signIn(const UserId('u-root'), isAdmin: true);
      await pump(tester, adminCubit(), AdministrationPage(onBack: () {}));

      await tester.tap(find.text('Create a club'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ' ');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('A name is required.'), findsOneWidget);
      expect(
        world.store.documents.keys.where(
          (p) => p.split('/').length == 2 && p.startsWith('clubs/'),
        ),
        hasLength(1),
      );
    });

    testWidgets('cancelling the creation does nothing', (tester) async {
      world.scope.signIn(const UserId('u-root'), isAdmin: true);
      await pump(tester, adminCubit(), AdministrationPage(onBack: () {}));

      await tester.tap(find.text('Create a club'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        world.store.documents.keys.where(
          (p) => p.split('/').length == 2 && p.startsWith('clubs/'),
        ),
        hasLength(1),
      );
    });

    testWidgets('a service failure is announced', (tester) async {
      world.scope.signIn(const UserId('u-root'), isAdmin: true);
      world.store.failing = StoreFailureCode.unavailable;
      await pump(tester, adminCubit(), AdministrationPage(onBack: () {}));

      expect(
        find.text(
          'The service is not responding. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a wait while loading', (tester) async {
      world.scope.signIn(const UserId('u-root'), isAdmin: true);
      final cubit = adminCubit(load: false);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: AdministrationPage(onBack: () {}),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
