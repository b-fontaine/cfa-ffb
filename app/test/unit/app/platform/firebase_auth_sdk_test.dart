import 'dart:async';

import 'package:billard_cfa/app/platform/firebase_auth_sdk.dart';
import 'package:billard_cfa/entities/account/data/auth_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements FirebaseAuth;

class _MockUser extends Mock implements User;

class _MockCredential extends Mock implements UserCredential;

void main() {
  late _MockAuth auth;
  late _MockUser user;
  late FirebaseAuthSdk sdk;

  setUp(() {
    auth = _MockAuth();
    user = _MockUser();
    when(() => user.uid).thenReturn('u1');
    when(() => user.email).thenReturn('coach@example.org');
    when(() => user.emailVerified).thenReturn(true);
    sdk = FirebaseAuthSdk(auth: () => auth);
  });

  UserCredential credential() {
    final credential = _MockCredential();
    when(() => credential.user).thenReturn(user);
    return credential;
  }

  test('userChanges maps users, and a missing user to null', () async {
    final controller = StreamController<User?>();
    when(() => auth.userChanges()).thenAnswer((_) => controller.stream);
    final seen = <AuthSdkUser?>[];
    final subscription = sdk.userChanges().listen(seen.add);

    controller
      ..add(user)
      ..add(null);
    await pumpEventQueue();
    await subscription.cancel();
    await controller.close();

    expect(seen.first?.uid, 'u1');
    expect(seen.first?.email, 'coach@example.org');
    expect(seen.first?.emailVerified, isTrue);
    expect(seen.last, isNull);
  });

  test('signInWithPassword signs in and maps the user', () async {
    when(
      () => auth.signInWithEmailAndPassword(
        email: 'coach@example.org',
        password: 'pw',
      ),
    ).thenAnswer((_) async => credential());

    final result = await sdk.signInWithPassword('coach@example.org', 'pw');

    expect(result.uid, 'u1');
  });

  test('createUser creates the user and maps it', () async {
    when(
      () => auth.createUserWithEmailAndPassword(
        email: 'new@example.org',
        password: 'pw',
      ),
    ).thenAnswer((_) async => credential());

    expect((await sdk.createUser('new@example.org', 'pw')).uid, 'u1');
  });

  test('sendEmailVerification goes to the current user', () async {
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.sendEmailVerification()).thenAnswer((_) async {});

    await sdk.sendEmailVerification();

    verify(() => user.sendEmailVerification()).called(1);
  });

  test('sendEmailVerification without a user is an SDK error', () async {
    when(() => auth.currentUser).thenReturn(null);

    await expectLater(
      sdk.sendEmailVerification(),
      throwsA(
        isA<AuthSdkException>().having(
          (e) => e.code,
          'code',
          'no-current-user',
        ),
      ),
    );
  });

  test('sendPasswordResetEmail and signOut delegate', () async {
    when(() => auth.sendPasswordResetEmail(email: 'a@b.cd'))
        .thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async {});

    await sdk.sendPasswordResetEmail('a@b.cd');
    await sdk.signOut();

    verify(() => auth.sendPasswordResetEmail(email: 'a@b.cd')).called(1);
    verify(() => auth.signOut()).called(1);
  });

  test(
    'a FirebaseAuthException becomes an AuthSdkException with its code',
    () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        FirebaseAuthException(code: 'invalid-credential', message: 'm'),
      );

      await expectLater(
        sdk.signInWithPassword('a@b.cd', 'pw'),
        throwsA(
          isA<AuthSdkException>()
              .having((e) => e.code, 'code', 'invalid-credential')
              .having(
                (e) => e.toString(),
                'text',
                contains('invalid-credential'),
              ),
        ),
      );
    },
  );
}
