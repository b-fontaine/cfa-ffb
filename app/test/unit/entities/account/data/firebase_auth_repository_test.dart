import 'dart:async';

import 'package:billard_cfa/entities/account/data/auth_sdk.dart';
import 'package:billard_cfa/entities/account/data/firebase_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

/// SDK scripté : chaque opération renvoie ce qu'on lui a demandé, ou lève le
/// code d'erreur donné.
class _ScriptedSdk implements AuthSdk {
  final StreamController<AuthSdkUser?> users = StreamController<AuthSdkUser?>();
  AuthSdkUser user = const AuthSdkUser(
    uid: 'u1',
    email: 'coach@example.org',
    emailVerified: true,
  );
  String? failWith;
  final List<String> calls = [];

  void _maybeFail() {
    final code = failWith;
    if (code != null) throw AuthSdkException(code);
  }

  @override
  Stream<AuthSdkUser?> userChanges() => users.stream;

  @override
  Future<AuthSdkUser> signInWithPassword(String email, String password) async {
    calls.add('signIn $email');
    _maybeFail();
    return user;
  }

  @override
  Future<AuthSdkUser> createUser(String email, String password) async {
    calls.add('create $email');
    _maybeFail();
    return user;
  }

  @override
  Future<void> sendEmailVerification() async {
    calls.add('verify');
    _maybeFail();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    calls.add('reset $email');
    _maybeFail();
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _maybeFail();
  }
}

void main() {
  late _ScriptedSdk sdk;
  late FirebaseAuthRepository repository;

  setUp(() {
    sdk = _ScriptedSdk();
    repository = FirebaseAuthRepository(sdk);
  });

  Future<AuthFailureCode> codeOf(Future<Object?> Function() body) async {
    try {
      await body();
    } on AuthFailure catch (failure) {
      return failure.code;
    }
    fail('un AuthFailure était attendu');
  }

  group('watchAccount', () {
    test('maps SDK users to accounts, and no user to null', () async {
      final seen = <Account?>[];
      final subscription = repository.watchAccount().listen(seen.add);

      sdk.users
        ..add(
          const AuthSdkUser(
            uid: 'u1',
            email: 'coach@example.org',
            emailVerified: false,
          ),
        )
        ..add(null);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [
        const Account(
          id: UserId('u1'),
          email: 'coach@example.org',
          emailVerified: false,
        ),
        null,
      ]);
    });

    test('a user without an address is treated as signed out', () async {
      final seen = <Account?>[];
      final subscription = repository.watchAccount().listen(seen.add);

      sdk.users.add(
        const AuthSdkUser(uid: 'u1', email: null, emailVerified: true),
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [null]);
    });
  });

  group('signIn', () {
    test('returns the account of the SDK user', () async {
      final account = await repository.signIn(
        email: 'coach@example.org',
        password: 'pw',
      );

      expect(account.id, const UserId('u1'));
      expect(account.emailVerified, isTrue);
      expect(sdk.calls, ['signIn coach@example.org']);
    });

    test('a user without an address is refused', () async {
      sdk.user = const AuthSdkUser(uid: 'u', email: '', emailVerified: true);

      expect(
        await codeOf(() => repository.signIn(email: 'a@b.c', password: 'pw')),
        AuthFailureCode.unavailable,
      );
    });

    test('every credential problem is the same generic failure', () async {
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'user-disabled',
        'invalid-email',
        'invalid-login-credentials',
      ]) {
        sdk.failWith = code;
        expect(
          await codeOf(() => repository.signIn(email: 'a@b.c', password: 'pw')),
          AuthFailureCode.invalidCredentials,
          reason: code,
        );
      }
    });

    test('transport failures stay distinct', () async {
      sdk.failWith = 'network-request-failed';
      expect(
        await codeOf(() => repository.signIn(email: 'a@b.c', password: 'pw')),
        AuthFailureCode.network,
      );
      sdk.failWith = 'too-many-requests';
      expect(
        await codeOf(() => repository.signIn(email: 'a@b.c', password: 'pw')),
        AuthFailureCode.tooManyRequests,
      );
    });

    test('an unknown code is "unavailable", never a cause', () async {
      sdk.failWith = 'something-new';

      final failure = await repository
          .signIn(email: 'a@b.c', password: 'pw')
          .then<AuthFailure?>(
            (_) => null,
            onError: (Object e) => e as AuthFailure,
          );

      expect(failure?.code, AuthFailureCode.unavailable);
    });
  });

  group('register', () {
    test('returns the new account', () async {
      final account = await repository.register(
        email: 'new@example.org',
        password: 'long-enough-password',
      );

      expect(account.email, 'coach@example.org');
      expect(sdk.calls, ['create new@example.org']);
    });

    test('an address already in use does not say so', () async {
      sdk.failWith = 'email-already-in-use';
      expect(
        await codeOf(() => repository.register(email: 'a@b.c', password: 'pw')),
        AuthFailureCode.registrationFailed,
      );
    });

    test('maps the other registration codes', () async {
      final expected = {
        'weak-password': AuthFailureCode.weakPassword,
        'invalid-email': AuthFailureCode.invalidEmail,
        'operation-not-allowed': AuthFailureCode.registrationFailed,
        'network-request-failed': AuthFailureCode.network,
        'too-many-requests': AuthFailureCode.tooManyRequests,
        'other': AuthFailureCode.unavailable,
      };
      for (final entry in expected.entries) {
        sdk.failWith = entry.key;
        expect(
          await codeOf(
            () => repository.register(email: 'a@b.c', password: 'pw'),
          ),
          entry.value,
          reason: entry.key,
        );
      }
    });
  });

  group('sendPasswordReset', () {
    test('asks the SDK to send the e-mail', () async {
      await repository.sendPasswordReset('coach@example.org');

      expect(sdk.calls, ['reset coach@example.org']);
    });

    test('an unknown or refused address looks like a success', () async {
      for (final code in [
        'user-not-found',
        'invalid-email',
        'invalid-credential',
        'missing-email',
      ]) {
        sdk.failWith = code;
        await repository.sendPasswordReset('nobody@example.org');
      }
    });

    test('failures that do not depend on the address are reported', () async {
      sdk.failWith = 'network-request-failed';
      expect(
        await codeOf(() => repository.sendPasswordReset('a@b.c')),
        AuthFailureCode.network,
      );
      sdk.failWith = 'too-many-requests';
      expect(
        await codeOf(() => repository.sendPasswordReset('a@b.c')),
        AuthFailureCode.tooManyRequests,
      );
    });
  });

  group('sendEmailVerification and signOut', () {
    test('call the SDK', () async {
      await repository.sendEmailVerification();
      await repository.signOut();

      expect(sdk.calls, ['verify', 'signOut']);
    });

    test('translate the SDK errors', () async {
      sdk.failWith = 'network-request-failed';
      expect(
        await codeOf(repository.sendEmailVerification),
        AuthFailureCode.network,
      );
      sdk.failWith = 'no-current-user';
      expect(await codeOf(repository.signOut), AuthFailureCode.unavailable);
    });
  });
}
