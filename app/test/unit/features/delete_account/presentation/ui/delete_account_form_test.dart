import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:billard_cfa/features/delete_account/presentation/bloc/delete_account_state.dart';
import 'package:billard_cfa/features/delete_account/presentation/ui/delete_account_form.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../shared/ui/pump_ui.dart';

const _confirm = 'Delete my account permanently';

void main() {
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<List<String>> pump(
    WidgetTester tester, {
    DeleteAccountState state = const DeleteAccountState.idle(),
  }) async {
    final submitted = <String>[];
    await pumpUi(
      tester,
      SingleChildScrollView(
        child: DeleteAccountForm(state: state, onSubmit: submitted.add),
      ),
    );
    return submitted;
  }

  group('DeleteAccountForm', () {
    testWidgets('says what is deleted and what stays with the club', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(en.deleteAccountIntro), findsOneWidget);
      expect(find.text(en.deleteAccountStays), findsOneWidget);
      expect(find.text('Your password'), findsOneWidget);
    });

    testWidgets('submits the password by the button or the keyboard', (
      tester,
    ) async {
      final submitted = await pump(tester);
      await tester.enterText(find.byType(TextField), 'secret');

      await tester.tap(find.text(_confirm));
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(submitted, ['secret', 'secret']);
    });

    testWidgets('an empty password is asked for, nothing is submitted', (
      tester,
    ) async {
      final submitted = await pump(tester);

      await tester.tap(find.text(_confirm));
      await tester.pump();

      expect(find.text('Enter your password.'), findsOneWidget);
      expect(submitted, isEmpty);
    });

    testWidgets('while working: the step is announced, nothing can be '
        'submitted again', (tester) async {
      final submitted = await pump(
        tester,
        state: const DeleteAccountState.working(
          AccountDeletionStep.leavingClub(
            clubName: 'Club Nice',
            index: 1,
            count: 2,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'secret');

      await tester.tap(find.text(_confirm));

      expect(find.text('Leaving Club Nice (1 of 2)…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(submitted, isEmpty);
      final live = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Leaving Club Nice (1 of 2)…'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(live.flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('a refusal is an attention alert, a failure a persistent one', (
      tester,
    ) async {
      await pump(
        tester,
        state: const DeleteAccountState.stopped(
          AccountDeletionResult.refused(
            AccountDeletionRefusal.lastDirector,
            clubName: 'Club Nice',
          ),
        ),
      );
      expect(find.text(en.alertAttention), findsOneWidget);
      expect(
        find.text(en.deleteAccountRefusedLastDirector('Club Nice')),
        findsOneWidget,
      );

      await pump(
        tester,
        state: const DeleteAccountState.stopped(
          AccountDeletionResult.failed(AccountDeletionError.wrongPassword),
        ),
      );
      expect(find.text(en.alertPersistent), findsOneWidget);
      expect(find.text(en.deleteAccountWrongPassword), findsOneWidget);
    });

    testWidgets('once deleted, the form is closed', (tester) async {
      final submitted = await pump(
        tester,
        state: const DeleteAccountState.deleted(),
      );

      await tester.tap(find.text(_confirm));

      expect(find.text('Your account has been deleted.'), findsOneWidget);
      expect(submitted, isEmpty);
    });
  });

  group('deletionResultMessage', () {
    test('every outcome has its own message, saying what was deleted', () {
      const results = [
        AccountDeletionResult.deleted(),
        AccountDeletionResult.refused(AccountDeletionRefusal.unsentWrites),
        AccountDeletionResult.refused(AccountDeletionRefusal.administrator),
        AccountDeletionResult.refused(
          AccountDeletionRefusal.lastDirector,
          clubName: 'Club Nice',
        ),
        AccountDeletionResult.failed(AccountDeletionError.wrongPassword),
        AccountDeletionResult.failed(AccountDeletionError.tooManyRequests),
        AccountDeletionResult.failed(
          AccountDeletionError.passwordCheckExpired,
          progress: AccountDeletionProgress.clubDataRemoved,
        ),
        AccountDeletionResult.failed(AccountDeletionError.network),
        AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        ),
        AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataRemoved,
        ),
        AccountDeletionResult.failed(AccountDeletionError.unavailable),
        AccountDeletionResult.failed(
          AccountDeletionError.unavailable,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        ),
        AccountDeletionResult.failed(
          AccountDeletionError.unavailable,
          progress: AccountDeletionProgress.clubDataRemoved,
        ),
      ];

      final messages = [
        for (final result in results) deletionResultMessage(en, result),
      ];

      expect(messages.toSet(), hasLength(results.length));
      expect(
        messages[1],
        'Some changes made on this device have not been sent yet. Go back '
        'online, wait until they are sent, then try again. Nothing has been '
        'deleted.',
      );
      expect(
        messages[3],
        'You are the last director of Club Nice. Ask the administrator to '
        'appoint another director, then try again. Nothing has been deleted.',
      );
      expect(messages[7], contains('nothing has been deleted'));
      expect(messages[8], contains('may already be removed'));
      expect(messages[9], startsWith('Your club data has been removed'));
      expect(messages[10], contains('nothing has been deleted'));
      expect(messages[11], contains('may already be removed'));
      expect(messages[12], startsWith('Your club data has been removed'));
    });

    test('for every error, the message says what the progress says was '
        'deleted, never more nor less', () {
      for (final error in AccountDeletionError.values) {
        final nothing = deletionResultMessage(
          en,
          AccountDeletionResult.failed(error),
        );
        final partly = deletionResultMessage(
          en,
          AccountDeletionResult.failed(
            error,
            progress: AccountDeletionProgress.clubDataPartlyRemoved,
          ),
        );
        final removed = deletionResultMessage(
          en,
          AccountDeletionResult.failed(
            error,
            progress: AccountDeletionProgress.clubDataRemoved,
          ),
        );

        expect(
          nothing.toLowerCase(),
          contains('nothing has been deleted'),
          reason: '$error, nothing deleted',
        );
        expect(nothing, isNot(contains('club data has been removed')));
        expect(
          partly,
          contains('may already be removed'),
          reason: '$error, part-way',
        );
        expect(partly.toLowerCase(), isNot(contains('nothing has been')));
        expect(
          removed,
          startsWith('Your club data has been removed'),
          reason: '$error, club data removed',
        );
        expect(removed.toLowerCase(), isNot(contains('nothing has been')));
        expect({nothing, partly, removed}, hasLength(3));
      }
    });

    test('every step has its label', () {
      expect(
        deletionStepLabel(en, const AccountDeletionStep.checkingIdentity()),
        'Checking your password…',
      );
      expect(
        deletionStepLabel(en, const AccountDeletionStep.removingAccount()),
        'Deleting the account…',
      );
      expect(
        deletionStepLabel(
          en,
          const AccountDeletionStep.leavingClub(index: 2, count: 3),
        ),
        'Leaving a deleted or unnamed club (2 of 3)…',
      );
    });
  });
}
