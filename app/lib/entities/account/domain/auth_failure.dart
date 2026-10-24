/// Code stable d'un échec d'authentification, **distinct** d'`InvariantCode`
/// (ADR 0024, décision 31) : il ne dit jamais plus que ce que l'utilisateur
/// peut apprendre sans compromettre un compte.
///
/// Anti-énumération : « compte inconnu », « mauvais mot de passe » et « compte
/// désactivé » donnent tous [invalidCredentials] ; une adresse déjà utilisée
/// à l'inscription donne [registrationFailed] ; la demande de réinitialisation
/// ne distingue jamais une adresse connue d'une inconnue.
enum AuthFailureCode {
  /// Adresse ou mot de passe incorrects (cause volontairement non précisée).
  invalidCredentials,

  /// Identifiants justes, mais l'adresse n'est pas encore vérifiée.
  emailNotVerified,

  /// L'adresse saisie n'a pas la forme d'une adresse e-mail.
  invalidEmail,

  /// Mot de passe trop court à l'inscription (moins de dix caractères).
  weakPassword,

  /// Le code d'invitation n'a pas la forme attendue.
  invalidInvitationCode,

  /// Création du compte impossible (cause non précisée : adresse déjà
  /// utilisée, inscription refusée par le fournisseur…).
  registrationFailed,

  /// Trop de tentatives : le fournisseur demande d'attendre.
  tooManyRequests,

  /// Pas de réseau.
  network,

  /// L'opération sensible (suppression du compte) exige une vérification
  /// récente du mot de passe : la redemander (`requires-recent-login`).
  recentLoginRequired,

  /// Tout autre échec du fournisseur.
  unavailable,
}

/// Échec d'authentification attendu (levé par les dépôts et les cas d'usage).
class AuthFailure implements Exception {
  const AuthFailure(this.code, [this.detail]);

  final AuthFailureCode code;

  /// Précision technique pour le diagnostic (jamais affichée).
  final String? detail;

  @override
  String toString() => detail == null
      ? 'AuthFailure(${code.name})'
      : 'AuthFailure(${code.name}: $detail)';
}
