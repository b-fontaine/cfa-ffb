/// Quantité de bille : part de la bille cible recouverte par la blanche.
///
/// Dart pur : source unique, partagée par le petit schéma de quantité de bille,
/// le modèle de schéma d'exercice et les illustrations des séances.
enum ContactFraction {
  full(1),
  threeQuarter(0.75),
  half(0.5),
  quarter(0.25),
  thin(0.05);

  ContactFraction(this.overlap);

  /// Recouvrement, de 0 (effleurement) à 1 (bille pleine).
  final double overlap;

  /// Décalage entre les centres, perpendiculairement à la ligne de visée, en
  /// rayons de bille : 0 pour la bille pleine, 1 pour la demi-bille.
  double get centerOffset => 2 * (1 - overlap);
}
