/// Code stable d'une règle métier violée.
///
/// L'interface traduit ces codes via les ARB ; le domaine ne porte aucun texte.
enum InvariantCode {
  blankName,
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
  invalidRules,
  noStudents,
  nothingToTeach,
  backupUnreadable,
  backupVersionUnsupported,
  backupInvalid,
  backupInconsistent,
}

/// Échec métier attendu (sceller : un `switch` exhaustif suffit à le traiter).
sealed class Failure implements Exception {
  const Failure();
}

/// Une règle métier ou un invariant est violé.
final class InvariantViolation extends Failure {
  const InvariantViolation(this.code);

  final InvariantCode code;

  @override
  String toString() => 'InvariantViolation(${code.name})';
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
