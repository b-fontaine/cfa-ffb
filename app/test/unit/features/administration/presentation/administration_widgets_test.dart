import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/features/administration/presentation/bloc/administration_state.dart';
import 'package:billard_cfa/features/administration/presentation/ui/administered_club_card.dart';
import 'package:billard_cfa/features/administration/presentation/ui/create_club_dialog.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

void main() {
  IssuedInvitationStatus item(String code, InvitationStatus? status) =>
      IssuedInvitationStatus(
        IssuedInvitation(
          code: InvitationCode.tryParse(code)!,
          role: Role.director,
          createdAt: DateTime(2026, 10, 12),
          expiresAt: DateTime(2026, 10, 14),
        ),
        status,
      );

  group('AdministeredClubCard', () {
    testWidgets('shows the club, invites a director, lists the invitations', (
      tester,
    ) async {
      var invited = 0;
      final revoked = <InvitationCode>[];
      await pumpUi(
        tester,
        SingleChildScrollView(
          child: AdministeredClubCard(
            entry: AdministeredClub(
              club: Club(id: const ClubId('c1'), name: 'Club Nice'),
              invitations: [
                item('AAAAAAAAAA', InvitationStatus.waiting),
                item('BBBBBBBBBB', InvitationStatus.used),
                item('CCCCCCCCCC', InvitationStatus.expired),
                item('DDDDDDDDDD', null),
              ],
            ),
            onInviteDirector: () => invited++,
            onRevoke: revoked.add,
          ),
        ),
      );

      expect(find.text('Club Nice'), findsOneWidget);
      expect(
        find.text('Director invitations sent from this device'),
        findsOneWidget,
      );
      expect(find.text('Director · Waiting'), findsOneWidget);
      expect(find.text('Director · Used'), findsOneWidget);
      expect(find.text('Director · Expired'), findsOneWidget);
      expect(find.text('Director · Status unknown'), findsOneWidget);
      expect(find.text('Revoke'), findsNWidgets(2));

      await tester.tap(find.text('Invite a director'));
      await tester.tap(find.text('Revoke').first);
      expect(invited, 1);
      expect(revoked.single.value, 'AAAAAAAAAA');
    });

    testWidgets('a club with no invitation shows no list', (tester) async {
      await pumpUi(
        tester,
        AdministeredClubCard(
          entry: AdministeredClub(
            club: Club(id: const ClubId('c1'), name: 'Club Nice'),
          ),
          onInviteDirector: () {},
          onRevoke: (_) {},
        ),
      );

      expect(
        find.text('Director invitations sent from this device'),
        findsNothing,
      );
      expect(
        tester
            .getSize(find.widgetWithText(FilledButton, 'Invite a director'))
            .height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('showCreateClubDialog', () {
    Widget opener(void Function(String?) done) => Builder(
      builder: (context) => TextButton(
        onPressed: () async => done(await showCreateClubDialog(context)),
        child: const Text('open'),
      ),
    );

    testWidgets('returns the typed name', (tester) async {
      String? result;
      await pumpUi(tester, opener((value) => result = value));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).maxLength,
        maxClubNameLength,
      );
      await tester.enterText(find.byType(TextField), 'Club Nice');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(result, 'Club Nice');
    });

    testWidgets('cancelling and the keyboard', (tester) async {
      String? result = 'inchangé';
      await pumpUi(tester, opener((value) => result = value));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Autre');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, 'Autre');
    });
  });
}
