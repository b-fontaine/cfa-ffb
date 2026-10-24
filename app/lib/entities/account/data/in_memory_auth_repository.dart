import 'dart:async';

import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Authentification en mémoire (tests, BDD) : mêmes règles d'échec génériques
/// que l'implémentation Firebase, sans réseau.
@LazySingleton(as: AuthRepository, env: [Environment.test])
class InMemoryAuthRepository implements AuthRepository {
  final Map<String, _Record> _accounts = {};
  final StreamController<Account?> _changes =
      StreamController<Account?>.broadcast(sync: true);
  Account? _current;
  int _nextUid = 1;

  /// Adresses à qui un courriel de vérification a été envoyé, dans l'ordre.
  final List<String> verificationsSent = [];

  /// Adresses à qui un courriel de réinitialisation a été réellement envoyé
  /// (jamais une adresse inconnue, comme chez Firebase).
  final List<String> resetsSent = [];

  /// Quand il est vrai, toute opération échoue comme sans réseau.
  bool offline = false;

  /// Quand il est vrai, seul l'envoi du courriel de vérification échoue.
  bool verificationMailFails = false;

  /// Les comptes supprimés par leur titulaire, dans l'ordre (assertions).
  final List<Account> deletedAccounts = [];

  /// Fait échouer **une fois** la prochaine suppression du compte, avec ce
  /// code (coupure du réseau juste avant la suppression).
  AuthFailureCode? nextDeletionFailure;

  /// Ajoute un compte existant (préparation d'un scénario).
  Account seed({
    required String email,
    required String password,
    bool emailVerified = true,
    String? uid,
  }) {
    final account = Account(
      id: UserId(uid ?? 'user-${_nextUid++}'),
      email: _normalize(email),
      emailVerified: emailVerified,
    );
    _accounts[account.email] = _Record(account, password);
    return account;
  }

  /// Le compte d'adresse [email], `null` s'il n'existe pas.
  Account? accountOf(String email) => _accounts[_normalize(email)]?.account;

  /// Connecte directement un compte déjà ajouté (session persistée).
  void restoreSession(String email) {
    final record = _accounts[_normalize(email)]!;
    _current = record.account;
    _reauthenticated = false;
  }

  /// Le compte actuellement connecté.
  Account? get current => _current;

  @override
  Stream<Account?> watchAccount() {
    late final StreamController<Account?> controller;
    StreamSubscription<Account?>? subscription;
    controller = StreamController<Account?>(
      onListen: () {
        controller.add(_current);
        subscription = _changes.stream.listen(controller.add);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    _requireNetwork();
    final record = _accounts[_normalize(email)];
    if (record == null || record.password != password) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
    return _set(record.account);
  }

  @override
  Future<Account> register({
    required String email,
    required String password,
  }) async {
    _requireNetwork();
    final key = _normalize(email);
    if (_accounts.containsKey(key)) {
      throw const AuthFailure(AuthFailureCode.registrationFailed);
    }
    return _set(seed(email: email, password: password, emailVerified: false));
  }

  @override
  Future<void> sendEmailVerification() async {
    _requireNetwork();
    if (verificationMailFails) {
      throw const AuthFailure(AuthFailureCode.unavailable);
    }
    final account = _current;
    if (account == null) throw const AuthFailure(AuthFailureCode.unavailable);
    verificationsSent.add(account.email);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _requireNetwork();
    final key = _normalize(email);
    if (_accounts.containsKey(key)) resetsSent.add(key);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _reauthenticated = false;
    _changes.add(null);
  }

  /// Le mot de passe a été vérifié à nouveau depuis la dernière connexion
  /// (exigé par la suppression, comme la « connexion récente » de Firebase).
  bool _reauthenticated = false;

  @override
  Future<void> reauthenticate(String password) async {
    _requireNetwork();
    final account = _current;
    if (account == null) throw const AuthFailure(AuthFailureCode.unavailable);
    if (_accounts[account.email]?.password != password) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
    _reauthenticated = true;
  }

  @override
  Future<void> deleteAccount() async {
    _requireNetwork();
    final account = _current;
    if (account == null) throw const AuthFailure(AuthFailureCode.unavailable);
    if (!_reauthenticated) {
      throw const AuthFailure(AuthFailureCode.recentLoginRequired);
    }
    final failure = nextDeletionFailure;
    if (failure != null) {
      nextDeletionFailure = null;
      throw AuthFailure(failure);
    }
    _accounts.remove(account.email);
    deletedAccounts.add(account);
    _current = null;
    _reauthenticated = false;
    _changes.add(null);
  }

  /// Marque l'adresse comme vérifiée (le lien du courriel a été ouvert).
  void verify(String email) {
    final record = _accounts[_normalize(email)]!;
    _accounts[record.account.email] = _Record(
      Account(
        id: record.account.id,
        email: record.account.email,
        emailVerified: true,
      ),
      record.password,
    );
  }

  Account _set(Account account) {
    _current = account;
    _reauthenticated = false;
    _changes.add(account);
    return account;
  }

  void _requireNetwork() {
    if (offline) throw const AuthFailure(AuthFailureCode.network);
  }

  static String _normalize(String email) => email.trim().toLowerCase();
}

class _Record {
  const _Record(this.account, this.password);

  final Account account;
  final String password;
}
