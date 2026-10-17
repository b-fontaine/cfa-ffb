import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/ui/invitation_code_card.dart';
import 'package:billard_cfa/shared/ui/invitation_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  final code = InvitationCode.tryParse('ABCDEFGHJKMN')!;
  final until = DateTime(2026, 10, 14, 9, 30);
  String? copied;

  setUp(() {
    copied = null;
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text']! as String;
          }
          return null;
        });
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('InvitationCodeCard', () {
    testWidgets('shows the code by groups of four, its deadline and its help', (
      tester,
    ) async {
      await pumpUi(tester, InvitationCodeCard(code: code, validUntil: until));

      expect(find.text('Invitation code'), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byKey(invitationCodeKey)).data,
        'ABCD-EFGH-JKMN',
      );
      expect(find.text('Valid until Oct 14, 2026 09:30'), findsOneWidget);
      expect(
        find.text('Give this code to the person. It can be used once.'),
        findsOneWidget,
      );
    });

    testWidgets('in French, the deadline reads naturally', (tester) async {
      await pumpUi(
        tester,
        InvitationCodeCard(code: code, validUntil: until),
        locale: const Locale('fr'),
      );

      expect(find.textContaining('Valable jusqu’au'), findsOneWidget);
      expect(find.text('Copier le code'), findsOneWidget);
    });

    testWidgets('copies the code without dashes and confirms it', (
      tester,
    ) async {
      await pumpUi(tester, InvitationCodeCard(code: code, validUntil: until));

      await tester.tap(find.text('Copy the code'));
      await tester.pump();

      expect(copied, 'ABCDEFGHJKMN');
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('offers the link only when the web origin is known', (
      tester,
    ) async {
      await pumpUi(tester, InvitationCodeCard(code: code, validUntil: until));
      expect(find.text('Copy the link'), findsNothing);

      await pumpUi(
        tester,
        InvitationCodeCard(
          code: code,
          validUntil: until,
          linkFor: (code) => 'https://club.example/open/${code.value}',
        ),
      );
      await tester.tap(find.text('Copy the link'));
      await tester.pump();

      expect(copied, 'https://club.example/open/ABCDEFGHJKMN');
    });

    testWidgets('the code is read letter by letter, the buttons are 48 dp', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(
        tester,
        InvitationCodeCard(
          code: code,
          validUntil: until,
          linkFor: (code) => 'https://club.example/${code.value}',
        ),
      );

      expect(find.bySemanticsLabel('A B C D E F G H J K M N'), findsOneWidget);
      for (final button in [
        find.text('Copy the code'),
        find.text('Copy the link'),
      ]) {
        final target = find.ancestor(
          of: button,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
      semantics.dispose();
    });
  });

  group('InvitationRow', () {
    testWidgets('shows the code, the subtitle and revokes on tap', (
      tester,
    ) async {
      var revoked = 0;
      await pumpUi(
        tester,
        InvitationRow(
          code: 'ABCD-EFGH-JKMN',
          subtitle: 'Teacher · Waiting',
          revokeLabel: 'Revoke',
          onRevoke: () => revoked++,
        ),
      );

      expect(find.text('ABCD-EFGH-JKMN'), findsOneWidget);
      expect(find.text('Teacher · Waiting'), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Revoke')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Revoke'));
      expect(revoked, 1);
    });

    testWidgets('has no button when it cannot be revoked', (tester) async {
      await pumpUi(
        tester,
        const InvitationRow(
          code: 'ABCD-EFGH-JKMN',
          subtitle: 'Teacher · Used',
          revokeLabel: 'Revoke',
        ),
      );

      expect(find.text('Revoke'), findsNothing);
    });
  });
}
