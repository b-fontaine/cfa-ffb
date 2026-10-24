import 'dart:async';

import 'package:billard_cfa/entities/account/data/auth_sdk.dart';
import 'package:billard_cfa/entities/account/data/firebase_auth_repository.dart';
import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// SDK qui se comporte comme Firebase Auth pour la connexion : un compte connu
/// (`coach@example.org` / `correct-horse`), et le code d'erreur propre à
/// chaque cause (avec ou sans protection contre l'énumération).
class _FirebaseLikeSdk implements AuthSdk {
  _FirebaseLikeSdk({required this.unknownCode, required this.wrongCode});

  final String unknownCode;
  final String wrongCode;

  @override
  Stream<AuthSdkUser?> userChanges() => const Stream.empty();

  @override
  Future<AuthSdkUser> signInWithPassword(String email, String password) async {
    if (email != 'coach@example.org') throw AuthSdkException(unknownCode);
    if (password != 'correct-horse') throw AuthSdkException(wrongCode);
    return const AuthSdkUser(
      uid: 'u1',
      email: 'coach@example.org',
      emailVerified: true,
    );
  }

  @override
  Future<AuthSdkUser> createUser(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (email != 'coach@example.org') throw AuthSdkException(unknownCode);
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> reauthenticate(String password) async {
    if (password != 'correct-horse') throw AuthSdkException(wrongCode);
  }

  @override
  Future<void> deleteUser() async {}
}

/// Le contrat de connexion que **toute** implémentation d'`AuthRepository`
/// respecte : les BDD tournent sur le double en mémoire, la production sur
/// `FirebaseAuthRepository`. Une même suite sur les deux empêche que la preuve
/// des scénarios BDD (« mauvais mot de passe », « adresse inconnue ») repose
/// sur un double plus indulgent que l'implémentation réelle.
void _signInContract(String name, AuthRepository Function() create) {
  group('sign-in contract: $name', () {
    late AuthRepository repository;

    setUp(() => repository = create());

    Future<AuthFailure> failureOf(String email, String password) async {
      try {
        await repository.signIn(email: email, password: password);
      } on AuthFailure catch (failure) {
        return failure;
      }
      fail('un AuthFailure était attendu');
    }

    test('the right credentials sign in', () async {
      final account = await repository.signIn(
        email: 'coach@example.org',
        password: 'correct-horse',
      );

      expect(account.email, 'coach@example.org');
    });

    test('a wrong password and an unknown address fail identically', () async {
      final wrong = await failureOf('coach@example.org', 'not-the-password');
      final unknown = await failureOf('nobody@example.org', 'correct-horse');

      expect(wrong.code, AuthFailureCode.invalidCredentials);
      expect(unknown.code, wrong.code);
    });

    test('a password reset for an unknown address reveals nothing', () async {
      await repository.sendPasswordReset('nobody@example.org');
    });

    test(
      'reauthenticating with a wrong password is the sign-in failure',
      () async {
        await repository.signIn(
          email: 'coach@example.org',
          password: 'correct-horse',
        );

        try {
          await repository.reauthenticate('not-the-password');
          fail('un AuthFailure était attendu');
        } on AuthFailure catch (failure) {
          expect(failure.code, AuthFailureCode.invalidCredentials);
        }
        await repository.reauthenticate('correct-horse');
      },
    );
  });
}

AuthRepository _inMemory() {
  final repository = InMemoryAuthRepository()
    ..seed(email: 'coach@example.org', password: 'correct-horse');
  return repository;
}

void main() {
  _signInContract('in memory', _inMemory);

  // Les trois codes que Firebase renvoie selon la configuration du projet
  // (protection contre l'énumération active : `invalid-credential` partout).
  for (final (unknown, wrong) in const [
    ('invalid-credential', 'invalid-credential'),
    ('user-not-found', 'wrong-password'),
    ('invalid-login-credentials', 'invalid-login-credentials'),
  ]) {
    _signInContract(
      'firebase ($unknown / $wrong)',
      () => FirebaseAuthRepository(
        _FirebaseLikeSdk(unknownCode: unknown, wrongCode: wrong),
      ),
    );
  }
}
