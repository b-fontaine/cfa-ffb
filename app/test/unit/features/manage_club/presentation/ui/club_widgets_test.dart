import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/club_members_card.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/issued_invitations_card.dart';
import 'package:billard_cfa/features/manage_club/presentation/ui/rename_club_dialog.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../shared/ui/pump_ui.dart';

void main() {
  final sophie = Member(
    uid: const UserId('u-sophie'),
    role: Role.teacher,
    displayName: 'sophie',
  );
  final boss = Member(
    uid: const UserId('u-boss'),
    role: Role.director,
    displayName: 'Directrice',
  );

  group('ClubMembersCard', () {
    testWidgets('lists the name and the role of each member', (tester) async {
      await pumpUi(
        tester,
        ClubMembersCard(
          members: [boss, sophie],
          canRemove: (_) => false,
          onRemove: (_) {},
        ),
      );

      expect(find.text('Team and families'), findsOneWidget);
      expect(find.text('sophie'), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('Director'), findsOneWidget);
      expect(find.text('Remove access'), findsNothing);
    });

    testWidgets('an empty club says so', (tester) async {
      await pumpUi(
        tester,
        ClubMembersCard(
          members: const [],
          canRemove: (_) => true,
          onRemove: (_) {},
        ),
      );
      expect(find.text('Nobody has joined yet.'), findsOneWidget);
    });

    testWidgets('removal asks for a confirmation naming the person', (
      tester,
    ) async {
      final removed = <Member>[];
      await pumpUi(
        tester,
        ClubMembersCard(
          members: [boss, sophie],
          canRemove: (m) => m.role != Role.director,
          onRemove: removed.add,
        ),
      );

      expect(
        find.text('Remove access'),
        findsOneWidget,
        reason: 'pas pour le directeur',
      );
      await tester.tap(find.text('Remove access'));
      await tester.pumpAndSettle();
      expect(find.text('Remove sophie?'), findsOneWidget);
      expect(find.textContaining('loses access'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(removed, isEmpty);

      await tester.tap(find.text('Remove access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(removed, [sophie]);
    });

    testWidgets('the removal buttons are 48 dp', (tester) async {
      await pumpUi(
        tester,
        ClubMembersCard(
          members: [sophie],
          canRemove: (_) => true,
          onRemove: (_) {},
        ),
      );
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Remove access')).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('IssuedInvitationsCard', () {
    IssuedInvitationStatus item(
      String code,
      Role role,
      InvitationStatus? status,
    ) => IssuedInvitationStatus(
      IssuedInvitation(
        code: InvitationCode.tryParse(code)!,
        role: role,
        createdAt: DateTime(2026, 10, 12),
        expiresAt: DateTime(2026, 10, 14),
      ),
      status,
    );

    testWidgets('shows every state in words and revokes what can still serve', (
      tester,
    ) async {
      final revoked = <InvitationCode>[];
      await pumpUi(
        tester,
        SingleChildScrollView(
          child: IssuedInvitationsCard(
            title: 'Invitations sent from this device',
            invitations: [
              item('AAAAAAAAAA', Role.teacher, InvitationStatus.waiting),
              item('BBBBBBBBBB', Role.guardian, InvitationStatus.used),
              item('CCCCCCCCCC', Role.student, InvitationStatus.expired),
              item('DDDDDDDDDD', Role.teacher, null),
            ],
            onRevoke: revoked.add,
          ),
        ),
      );

      expect(find.text('Teacher · Waiting'), findsOneWidget);
      expect(find.text('Parent · Used'), findsOneWidget);
      expect(find.text('Student · Expired'), findsOneWidget);
      expect(find.text('Teacher · Status unknown'), findsOneWidget);
      expect(
        find.text('Revoke'),
        findsNWidgets(2),
        reason: 'en attente et inconnue',
      );

      await tester.tap(find.text('Revoke').first);
      expect(revoked.single.value, 'AAAAAAAAAA');
    });

    testWidgets('an empty list says so and explains the limit', (tester) async {
      await pumpUi(
        tester,
        IssuedInvitationsCard(
          title: 'Invitations sent from this device',
          invitations: const [],
          onRevoke: (_) {},
        ),
      );

      expect(
        find.text('No invitation sent from this device yet.'),
        findsOneWidget,
      );
      expect(find.textContaining('not listed on the server'), findsOneWidget);
    });
  });

  group('showRenameClubDialog', () {
    testWidgets('returns what was typed, starting from the current name', (
      tester,
    ) async {
      String? result;
      await pumpUi(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showRenameClubDialog(context, 'Club Nice'),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text('Club Nice'),
        findsOneWidget,
        reason: 'valeur de départ',
      );
      await tester.enterText(find.byType(TextField), 'Club Lyon');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 'Club Lyon');
    });

    testWidgets('cancelling returns null; the field is bounded', (
      tester,
    ) async {
      String? result = 'inchangé';
      await pumpUi(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showRenameClubDialog(context, 'Club Nice'),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).maxLength,
        maxClubNameLength,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('submitting from the keyboard validates', (tester) async {
      String? result;
      await pumpUi(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showRenameClubDialog(context, 'Club Nice'),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Autre');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(result, 'Autre');
    });
  });
}
