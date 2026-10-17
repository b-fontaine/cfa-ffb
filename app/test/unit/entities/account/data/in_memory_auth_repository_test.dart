import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryAuthRepository auth;

  setUp(() => auth = InMemoryAuthRepository());

  Future<AuthFailureCode> codeOf(Future<Object?> Function() body) async {
    try {
      await body();
    } on AuthFailure catch (failure) {
      return failure.code;
    }
    fail('un AuthFailure était attendu');
  }

  test('wrong password and unknown address are the same failure', () async {
    auth.seed(email: 'coach@example.org', password: 'right-password');

    expect(
      await codeOf(
        () => auth.signIn(email: 'coach@example.org', password: 'wrong'),
      ),
      AuthFailureCode.invalidCredentials,
    );
    expect(
      await codeOf(
        () => auth.signIn(email: 'nobody@example.org', password: 'x'),
      ),
      AuthFailureCode.invalidCredentials,
    );
  });

  test('the address is matched without case or surrounding spaces', () async {
    auth.seed(email: 'Coach@Example.org', password: 'pw');

    final account = await auth.signIn(
      email: ' coach@example.org ',
      password: 'pw',
    );

    expect(account.email, 'coach@example.org');
    expect(auth.current, account);
  });

  test(
    'watchAccount emits the persisted session first, then changes',
    () async {
      auth
        ..seed(email: 'coach@example.org', password: 'pw')
        ..restoreSession('coach@example.org');
      final seen = <Account?>[];
      final subscription = auth.watchAccount().listen(seen.add);
      await pumpEventQueue();

      await auth.signOut();
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen.map((a) => a?.email), ['coach@example.org', null]);
      expect(auth.current, isNull);
    },
  );

  test('register creates an unverified account and signs it in', () async {
    final account = await auth.register(
      email: 'new@example.org',
      password: 'pw',
    );

    expect(account.emailVerified, isFalse);
    expect(auth.current, account);
    expect(auth.accountOf('new@example.org'), account);
  });

  test(
    'register refuses an address already in use without saying why',
    () async {
      auth.seed(email: 'coach@example.org', password: 'pw');

      expect(
        await codeOf(
          () => auth.register(email: 'coach@example.org', password: 'other'),
        ),
        AuthFailureCode.registrationFailed,
      );
    },
  );

  test(
    'verify turns the account into a verified one at the next sign-in',
    () async {
      auth
        ..seed(email: 'new@example.org', password: 'pw', emailVerified: false)
        ..verify('new@example.org');
      final account = await auth.signIn(
        email: 'new@example.org',
        password: 'pw',
      );

      expect(account.emailVerified, isTrue);
    },
  );

  test('a verification e-mail goes to the signed-in account only', () async {
    expect(
      await codeOf(auth.sendEmailVerification),
      AuthFailureCode.unavailable,
    );
    auth.seed(email: 'new@example.org', password: 'pw', emailVerified: false);
    await auth.signIn(email: 'new@example.org', password: 'pw');

    await auth.sendEmailVerification();

    expect(auth.verificationsSent, ['new@example.org']);
  });

  test('a reset e-mail is only sent to a known address', () async {
    auth.seed(email: 'coach@example.org', password: 'pw');

    await auth.sendPasswordReset('nobody@example.org');
    await auth.sendPasswordReset('Coach@example.org');

    expect(auth.resetsSent, ['coach@example.org']);
  });

  test('offline, every network operation fails the same way', () async {
    auth
      ..seed(email: 'coach@example.org', password: 'pw')
      ..offline = true;

    expect(
      await codeOf(
        () => auth.signIn(email: 'coach@example.org', password: 'pw'),
      ),
      AuthFailureCode.network,
    );
    expect(
      await codeOf(() => auth.register(email: 'a@b.c', password: 'pw')),
      AuthFailureCode.network,
    );
    expect(await codeOf(auth.sendEmailVerification), AuthFailureCode.network);
    expect(
      await codeOf(() => auth.sendPasswordReset('a@b.c')),
      AuthFailureCode.network,
    );
  });
}
