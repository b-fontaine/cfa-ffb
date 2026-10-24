import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';

/// Port de l'authentification (ADR 0024) : e-mail et mot de passe seulement.
///
/// Toute erreur attendue est un `AuthFailure` ; aucune cause n'est révélée au
/// delà de ce que `AuthFailureCode` autorise.
abstract interface class AuthRepository {
  /// Le compte connecté, sans attendre le réseau : la session persistée sur
  /// l'appareil sort en premier (démarrage hors ligne), puis chaque connexion
  /// ou déconnexion. `null` : personne n'est connecté.
  Stream<Account?> watchAccount();

  /// Connecte. Ne vérifie pas l'adresse : le compte renvoyé dit s'il l'est.
  Future<Account> signIn({required String email, required String password});

  /// Crée un compte et le connecte (adresse non vérifiée).
  Future<Account> register({required String email, required String password});

  /// Envoie (ou renvoie) le courriel de vérification au compte connecté.
  Future<void> sendEmailVerification();

  /// Demande le courriel de réinitialisation. Aboutit de la même façon que
  /// l'adresse existe ou non (anti-énumération).
  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  /// Vérifie à nouveau le mot de passe du compte connecté (réauthentification),
  /// juste avant une opération sensible : la suppression du compte
  /// (FB8 partie B). Un mauvais mot de passe donne
  /// [AuthFailureCode.invalidCredentials], comme à la connexion.
  Future<void> reauthenticate(String password);

  /// Supprime **définitivement** le compte connecté (après [reauthenticate]) ;
  /// la session se ferme avec lui. Une vérification trop ancienne donne
  /// [AuthFailureCode.recentLoginRequired].
  Future<void> deleteAccount();
}
