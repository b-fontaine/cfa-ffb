import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/data/key_value_pending_invitations.dart';
import 'package:billard_cfa/features/sign_in/domain/register_with_invitation.dart';
import 'package:billard_cfa/features/sign_in/domain/request_password_reset.dart';
import 'package:billard_cfa/features/sign_in/domain/resend_verification.dart';
import 'package:billard_cfa/features/sign_in/domain/sign_in.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _failure(AuthFailureCode code) =>
    isA<AuthFailure>().having((f) => f.code, 'code', code);

void main() {
  late InMemoryAuthRepository auth;
  late InMemoryKeyValueStore store;
  late KeyValuePendingInvitations pending;

  setUp(() {
    auth = InMemoryAuthRepository();
    store = InMemoryKeyValueStore();
    pending = KeyValuePendingInvitations(store);
  });

  group('SignIn', () {
    test('signs a verified account in', () async {
      auth.seed(email: 'coach@example.org', password: 'pw');

      final account = await SignIn(auth)(
        email: ' coach@example.org ',
        password: 'pw',
      );

      expect(account.email, 'coach@example.org');
      expect(auth.current, account);
    });

    test('an unverified address is signed out at once', () async {
      auth.seed(email: 'new@example.org', password: 'pw', emailVerified: false);

      await expectLater(
        SignIn(auth)(email: 'new@example.org', password: 'pw'),
        throwsA(_failure(AuthFailureCode.emailNotVerified)),
      );
      expect(auth.current, isNull);
    });

    test(
      'an unverified address with a wrong password learns nothing',
      () async {
        auth.seed(
          email: 'new@example.org',
          password: 'pw',
          emailVerified: false,
        );

        await expectLater(
          SignIn(auth)(email: 'new@example.org', password: 'wrong'),
          throwsA(_failure(AuthFailureCode.invalidCredentials)),
        );
      },
    );

    test('a malformed address is refused before any request', () async {
      await expectLater(
        SignIn(auth)(email: 'nope', password: 'pw'),
        throwsA(_failure(AuthFailureCode.invalidEmail)),
      );
    });

    test('an empty password is the generic failure', () async {
      await expectLater(
        SignIn(auth)(email: 'a@b.cd', password: ''),
        throwsA(_failure(AuthFailureCode.invalidCredentials)),
      );
    });
  });

  group('ResendVerification', () {
    test('sends the e-mail then signs out', () async {
      auth.seed(email: 'new@example.org', password: 'pw', emailVerified: false);

      final sent = await ResendVerification(auth)(
        email: 'new@example.org',
        password: 'pw',
      );

      expect(sent, isTrue);
      expect(auth.verificationsSent, ['new@example.org']);
      expect(auth.current, isNull);
    });

    test('sends nothing to an address that is already verified', () async {
      auth.seed(email: 'coach@example.org', password: 'pw');

      final sent = await ResendVerification(auth)(
        email: 'coach@example.org',
        password: 'pw',
      );

      expect(sent, isFalse);
      expect(auth.verificationsSent, isEmpty);
      expect(auth.current, isNull);
    });

    test('needs the right password, like a sign-in', () async {
      auth.seed(email: 'new@example.org', password: 'pw', emailVerified: false);

      await expectLater(
        ResendVerification(auth)(email: 'new@example.org', password: 'wrong'),
        throwsA(_failure(AuthFailureCode.invalidCredentials)),
      );
      expect(auth.verificationsSent, isEmpty);
    });

    test('a malformed address is refused', () async {
      await expectLater(
        ResendVerification(auth)(email: 'nope', password: 'pw'),
        throwsA(_failure(AuthFailureCode.invalidEmail)),
      );
    });
  });

  group('RequestPasswordReset', () {
    test('asks for the e-mail, trimmed', () async {
      auth.seed(email: 'coach@example.org', password: 'pw');

      await RequestPasswordReset(auth)(email: ' coach@example.org ');

      expect(auth.resetsSent, ['coach@example.org']);
    });

    test('an unknown address succeeds the same way', () async {
      await RequestPasswordReset(auth)(email: 'nobody@example.org');

      expect(auth.resetsSent, isEmpty);
    });

    test('a malformed address is refused', () async {
      await expectLater(
        RequestPasswordReset(auth)(email: 'nope'),
        throwsA(_failure(AuthFailureCode.invalidEmail)),
      );
    });
  });

  group('RegisterWithInvitation', () {
    Future<Registration> register({
      String code = 'abcd-efgh-jkmn',
      String email = 'new@example.org',
      String password = 'long-enough-password',
    }) => RegisterWithInvitation(auth, pending)(
      code: code,
      email: email,
      password: password,
    );

    test(
      'creates the account, keeps the code, sends the e-mail, signs out',
      () async {
        final registration = await register();

        final account = auth.accountOf('new@example.org')!;
        expect(registration.verificationSent, isTrue);
        expect(account.emailVerified, isFalse);
        expect((await pending.read(account.id))?.value, 'ABCDEFGHJKMN');
        expect(auth.verificationsSent, ['new@example.org']);
        expect(auth.current, isNull);
      },
    );

    test(
      'a verification e-mail that cannot leave is reported, not fatal',
      () async {
        auth.verificationMailFails = true;

        final registration = await register();

        final account = auth.accountOf('new@example.org')!;
        expect(registration.verificationSent, isFalse);
        expect((await pending.read(account.id))?.value, 'ABCDEFGHJKMN');
        expect(auth.current, isNull);
      },
    );

    test('a short password creates nothing', () async {
      await expectLater(
        register(password: 'too-short'),
        throwsA(_failure(AuthFailureCode.weakPassword)),
      );
      expect(auth.accountOf('new@example.org'), isNull);
    });

    test('a password of exactly 10 characters is accepted', () async {
      // Littéral, pas `minPasswordLength` : la borne est fixée à 10 (ADR 0024).
      await register(password: '0123456789');

      expect(auth.accountOf('new@example.org'), isNotNull);
    });

    test('a password of 9 characters is refused', () async {
      await expectLater(
        register(password: '012345678'),
        throwsA(_failure(AuthFailureCode.weakPassword)),
      );
      expect(auth.accountOf('new@example.org'), isNull);
    });

    test('a password of 11 characters is accepted', () async {
      await register(password: '01234567890');

      expect(auth.accountOf('new@example.org'), isNotNull);
    });

    test('a malformed code creates nothing', () async {
      await expectLater(
        register(code: '12'),
        throwsA(_failure(AuthFailureCode.invalidInvitationCode)),
      );
      expect(auth.accountOf('new@example.org'), isNull);
    });

    test('a malformed address creates nothing', () async {
      await expectLater(
        register(email: 'nope'),
        throwsA(_failure(AuthFailureCode.invalidEmail)),
      );
      expect(store.entries, isEmpty);
    });

    test(
      'an address already in use is a generic failure and keeps no code',
      () async {
        auth.seed(email: 'new@example.org', password: 'other');

        await expectLater(
          register(),
          throwsA(_failure(AuthFailureCode.registrationFailed)),
        );
        expect(store.entries, isEmpty);
      },
    );
  });

  group('KeyValuePendingInvitations', () {
    test('keeps and clears the code per account', () async {
      final account = auth.seed(email: 'new@example.org', password: 'pw');
      expect(await pending.read(account.id), isNull);

      await RegisterWithInvitation(auth, pending)(
        code: 'ABCDEFGHJK',
        email: 'other@example.org',
        password: 'long-enough-password',
      );
      expect(await pending.read(account.id), isNull);

      final other = auth.accountOf('other@example.org')!;
      expect((await pending.read(other.id))?.value, 'ABCDEFGHJK');
      await pending.clear(other.id);
      expect(await pending.read(other.id), isNull);
    });

    test('an unreadable stored code is ignored', () async {
      final account = auth.seed(email: 'new@example.org', password: 'pw');
      await store.write(KeyValuePendingInvitations.keyFor(account.id), '??');

      expect(await pending.read(account.id), isNull);
    });
  });
}
