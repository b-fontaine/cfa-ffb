/// Code stable d'une règle métier violée.
///
/// L'interface traduit ces codes via les ARB ; le domaine ne porte aucun texte.
enum InvariantCode {
  blankName,

  /// Un nom de club ou de membre est vide (le « prénom obligatoire » de
  /// [blankName] ne convient pas à un club).
  nameRequired,
  invalidPeriod,
  seasonOutsidePeriod,
  invalidRange,
  invalidExerciseRef,
  successRateOutOfRange,
  totalOutOfRange,
  totalBelowSheet,
  negativePotted,
  pottedExceedsTotal,
  invalidPassIndex,
  passesLimitReached,
  studentNotPresent,
  studentNotInGroup,
  unknownExercise,
  unknownBlock,
  unknownGroup,
  unknownSheet,
  audienceMismatch,
  emptyAudienceHistory,
  audienceUnchanged,
  audienceChangeNotChronological,
  membershipAlreadyOpen,
  membershipNotOpen,
  membershipPeriodInvalid,
  scoreOutOfRange,
  commentTooLong,
  dateInFuture,
  recallEqualsMainBlock,
  invalidCatalogue,
  invalidDiagram,
  invalidSheet,
  invalidRules,
  noStudents,
  nothingToTeach,
  backupUnreadable,
  backupVersionUnsupported,
  backupInvalid,
  backupInconsistent,
  backupUnknownSheet,
  backupReopensClosedSeason,
  blockAlreadyAcquired,
  backupUnknownBlock,
  alertNotActive,
  groupNameTaken,
  groupNotEmpty,
  groupHasRecords,
  groupHasPlanned,
  groupChoiceRequired,
  moveBeforeLastPresence,
  seasonClosed,
  seasonAlreadyClosed,

  /// Un nom (club, prénom d'élève, nom affiché) dépasse la longueur que les
  /// règles du serveur acceptent.
  nameTooLong,

  /// Une invitation ne respecte pas la forme que les règles du serveur
  /// acceptent (rôle, groupes, fiches).
  invalidInvitation,

  /// Le rôle courant ne permet pas cette action (inviter ce rôle, retirer un
  /// directeur, ouvrir un écran réservé : ADR 0024, décisions 6 et 14).
  actionNotAllowed,

  /// Une invitation d'élève exige la case « a 15 ans ou plus » (ADR 0025,
  /// décision 4) : sinon, inviter un parent.
  ageConfirmationRequired,

  /// Aucun élève n'est choisi pour une invitation d'élève ou de parent.
  studentChoiceRequired,

  /// Un texte à imprimer contient un caractère que la fonte du document ne
  /// sait pas dessiner (export PDF, ADR 0021).
  unprintableContent,
}

/// Échec métier attendu (sceller : un `switch` exhaustif suffit à le traiter).
sealed class Failure implements Exception {
  const Failure();
}

/// Une règle métier ou un invariant est violé.
final class InvariantViolation extends Failure {
  const InvariantViolation(this.code, [this.detail]);

  final InvariantCode code;

  /// Précision technique pour le diagnostic (jamais affichée à l'utilisateur).
  final String? detail;

  @override
  String toString() => detail == null
      ? 'InvariantViolation(${code.name})'
      : 'InvariantViolation(${code.name}: $detail)';
}

/// L'entité demandée n'existe pas.
final class NotFound extends Failure {
  const NotFound(this.kind, this.id);

  /// Nature de l'entité (`student`, `group`, `session`, `season`).
  final String kind;
  final String id;

  @override
  String toString() => 'NotFound($kind, $id)';
}

/// Pourquoi le service distant a échoué.
enum ServiceFailureCode {
  /// Réseau ou service injoignable.
  unavailable,

  /// Les règles du serveur refusent l'opération (rôle insuffisant, club
  /// différent, invitation non valable).
  denied,

  /// Toute autre erreur du service.
  other,
}

/// Le service distant (Firestore) n'a pas pu faire ce qu'on lui demandait.
final class ServiceFailure extends Failure {
  const ServiceFailure(this.code, [this.detail]);

  final ServiceFailureCode code;

  /// Précision technique pour le diagnostic (jamais affichée à l'utilisateur).
  final String? detail;

  @override
  String toString() => detail == null
      ? 'ServiceFailure(${code.name})'
      : 'ServiceFailure(${code.name}: $detail)';
}

/// Résultat d'un cas d'usage : une valeur ou un [Failure].
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}

/// Exécute [body] et convertit tout [Failure] levé en [Err].
Future<Result<T>> runGuarded<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on Failure catch (failure) {
    return Err(failure);
  }
}
