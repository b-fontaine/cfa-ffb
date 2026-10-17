/// Dit si l'on peut changer de club maintenant (ADR 0024, décision 22) : la
/// bascule est interdite pendant une séance guidée ou une saisie ouverte,
/// sinon l'interface reconstruite perdrait ce qui est en cours.
///
/// Implémentée dans la couche `app`, qui connaît les séances guidées.
abstract interface class ClubSwitchGuard {
  bool get isBlocked;
}
