/// Pourquoi une invitation n'a pas pu être acceptée.
enum InvitationFailureCode {
  /// Aucune invitation pour ce code (jamais créée, ou révoquée).
  notFound,

  /// L'invitation a expiré.
  expired,

  /// L'invitation a déjà servi.
  used,

  /// Le serveur refuse le lot (règles) : invitation non valable pour ce
  /// compte, compte déjà membre du club, ou invitation consommée entre-temps.
  refused,
}

/// Échec attendu de l'acceptation d'une invitation (le code ou le compte ne
/// convient pas) ; les pannes du service lèvent `ServiceFailure`.
class InvitationFailure implements Exception {
  const InvitationFailure(this.code);

  final InvitationFailureCode code;

  @override
  String toString() => 'InvitationFailure(${code.name})';
}
