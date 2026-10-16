/// Marqueur de parcours d'une séance du catalogue pour le groupe choisi.
/// Précédence : [next] > [done] > [upcoming].
enum JourneyMark {
  /// Déjà donnée au groupe (saisie avec séance et passage).
  done,

  /// La séance recommandée ensuite (la suggestion, ADR 0009).
  next,

  /// Pas encore donnée, pas recommandée.
  upcoming,
}
