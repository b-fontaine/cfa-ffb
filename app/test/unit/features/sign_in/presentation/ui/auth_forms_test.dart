import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/auth_form_state.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/account_section.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/auth_fields.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/forgot_password_form.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/register_form.dart';
import 'package:billard_cfa/features/sign_in/presentation/ui/sign_in_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../shared/ui/pump_ui.dart';

const _submitting = AuthFormState(status: AuthFormStatus.submitting);

AuthFormState _failed(AuthFailureCode code) =>
    AuthFormState(status: AuthFormStatus.failed, failure: code);

void main() {
  group('SignInForm', () {
    Future<List<String>> pump(
      WidgetTester tester, {
      AuthFormState state = const AuthFormState(),
    }) async {
      final calls = <String>[];
      await pumpUi(
        tester,
        SingleChildScrollView(
          child: SignInForm(
            state: state,
            onSubmit: (email, password) => calls.add('submit $email $password'),
            onResendVerification: (email, password) =>
                calls.add('resend $email $password'),
            onForgotPassword: () => calls.add('forgot'),
            onRegister: () => calls.add('register'),
          ),
        ),
      );
      return calls;
    }

    testWidgets('submits what was typed, by the button or the keyboard', (
      tester,
    ) async {
      final calls = await pump(tester);
      await tester.enterText(find.byType(TextField).at(0), 'a@b.cd');
      await tester.enterText(find.byType(TextField).at(1), 'secret');

      await tester.tap(find.text('Sign in'));
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(calls, ['submit a@b.cd secret', 'submit a@b.cd secret']);
    });

    testWidgets('the password is hidden', (tester) async {
      await pump(tester);

      final password = tester.widget<TextField>(find.byType(TextField).at(1));

      expect(password.obscureText, isTrue);
    });

    testWidgets('buttons and links are at least 48 dp high', (tester) async {
      await pump(tester);

      for (final label in [
        'Sign in',
        'Forgot your password?',
        'I have an invitation code',
      ]) {
        final size = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              )
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('while sending, nothing can be submitted', (tester) async {
      final calls = await pump(tester, state: _submitting);

      await tester.tap(find.text('Sign in'), warnIfMissed: false);
      await tester.tap(find.text('Forgot your password?'), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(calls, isEmpty);
      expect(find.text('Sending…'), findsOneWidget);
    });

    testWidgets('links lead to the other screens', (tester) async {
      final calls = await pump(tester);

      await tester.tap(find.text('Forgot your password?'));
      await tester.tap(find.text('I have an invitation code'));

      expect(calls, ['forgot', 'register']);
    });

    testWidgets('an unverified address offers to resend the e-mail', (
      tester,
    ) async {
      final calls = await pump(
        tester,
        state: _failed(AuthFailureCode.emailNotVerified),
      );
      await tester.enterText(find.byType(TextField).at(0), 'a@b.cd');
      await tester.enterText(find.byType(TextField).at(1), 'secret');

      await tester.tap(find.text('Resend the verification e-mail'));

      expect(calls, ['resend a@b.cd secret']);
    });

    testWidgets('other failures do not offer it', (tester) async {
      await pump(tester, state: _failed(AuthFailureCode.invalidCredentials));

      expect(find.text('Resend the verification e-mail'), findsNothing);
      expect(
        find.text('Incorrect e-mail address or password.'),
        findsOneWidget,
      );
    });

    testWidgets('the failure is announced as a live region', (tester) async {
      await pump(tester, state: _failed(AuthFailureCode.network));

      final semantics = tester.getSemantics(
        find.text('No Internet connection. Check your network and try again.'),
      );

      expect(semantics, isNotNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsWidgets,
      );
    });
  });

  group('ForgotPasswordForm', () {
    testWidgets('submits the address, then confirms generically', (
      tester,
    ) async {
      final sent = <String>[];
      await pumpUi(
        tester,
        SingleChildScrollView(
          child: ForgotPasswordForm(
            state: const AuthFormState(status: AuthFormStatus.done),
            onSubmit: sent.add,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'a@b.cd');

      await tester.tap(find.text('Send the link'));
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(sent, ['a@b.cd', 'a@b.cd']);
      expect(
        find.text(
          'If an account exists for this address, a reset e-mail has just '
          'been sent.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not submit while sending', (tester) async {
      final sent = <String>[];
      await pumpUi(
        tester,
        SingleChildScrollView(
          child: ForgotPasswordForm(state: _submitting, onSubmit: sent.add),
        ),
      );

      await tester.tap(find.text('Send the link'), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(sent, isEmpty);
    });
  });

  group('RegisterForm', () {
    Future<List<String>> pump(WidgetTester tester, AuthFormState state) async {
      final calls = <String>[];
      await pumpUi(
        tester,
        SingleChildScrollView(
          child: RegisterForm(
            state: state,
            onSubmit: (code, email, password) =>
                calls.add('$code|$email|$password'),
          ),
        ),
      );
      return calls;
    }

    testWidgets('submits code, address and password', (tester) async {
      final calls = await pump(tester, const AuthFormState());
      await tester.enterText(find.byType(TextField).at(0), 'ABCDEFGHJK');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.cd');
      await tester.enterText(
        find.byType(TextField).at(2),
        'long-enough-password',
      );

      await tester.tap(find.text('Create my account'));
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(calls, [
        'ABCDEFGHJK|a@b.cd|long-enough-password',
        'ABCDEFGHJK|a@b.cd|long-enough-password',
      ]);
    });

    testWidgets('the password field states the minimum length', (tester) async {
      await pump(tester, const AuthFormState());

      expect(find.text('At least 10 characters'), findsOneWidget);
    });

    testWidgets('once done, the button is off and the message says what next', (
      tester,
    ) async {
      final calls = await pump(
        tester,
        const AuthFormState(
          status: AuthFormStatus.done,
          verificationSent: true,
        ),
      );

      await tester.tap(find.text('Create my account'), warnIfMissed: false);

      expect(calls, isEmpty);
      expect(
        find.text(
          'Account created. Open the link in the verification e-mail, '
          'then sign in.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says so when the e-mail could not leave', (tester) async {
      await pump(tester, const AuthFormState(status: AuthFormStatus.done));

      expect(find.textContaining('could not be sent'), findsOneWidget);
    });

    testWidgets('does not submit while sending', (tester) async {
      final calls = await pump(tester, _submitting);

      await tester.tap(find.text('Create my account'), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(calls, isEmpty);
    });
  });

  group('AuthFormFeedback', () {
    testWidgets('shows nothing while editing', (tester) async {
      await pumpUi(
        tester,
        const AuthFormFeedback(state: AuthFormState(), success: 'ok'),
      );

      expect(find.text('ok'), findsNothing);
    });

    testWidgets('every failure code has a message', (tester) async {
      for (final code in AuthFailureCode.values) {
        await pumpUi(tester, AuthFormFeedback(state: _failed(code)));

        expect(find.byType(Text), findsWidgets, reason: code.name);
      }
    });
  });

  testWidgets('AccountSection shows the account and signs out', (tester) async {
    var signedOut = 0;
    await pumpUi(
      tester,
      AccountSection(
        email: 'a@b.cd',
        clubName: 'Club Nice',
        roleLabel: 'Director',
        onSignOut: () => signedOut++,
      ),
    );

    expect(find.text('Signed in: a@b.cd'), findsOneWidget);
    expect(find.text('Active club: Club Nice (Director)'), findsOneWidget);

    await tester.tap(find.text('Sign out'));

    expect(signedOut, 1);
  });

  testWidgets('AccountSection offers the account deletion only when given', (
    tester,
  ) async {
    var opened = 0;
    await pumpUi(
      tester,
      AccountSection(
        email: 'a@b.cd',
        clubName: 'Club Nice',
        roleLabel: 'Director',
        onSignOut: () {},
      ),
    );
    expect(find.text('Delete my account'), findsNothing);

    await pumpUi(
      tester,
      AccountSection(
        email: 'a@b.cd',
        clubName: 'Club Nice',
        roleLabel: 'Director',
        onSignOut: () {},
        onDeleteAccount: () => opened++,
      ),
    );
    await tester.tap(find.text('Delete my account'));

    expect(opened, 1);
  });
}
