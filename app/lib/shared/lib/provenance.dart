/// Provenance d'un élément du contenu (hiérarchie des sources du projet).
///
/// `s` : PDF fédéraux (rang 1). `ffb` : ffbillard.com. `web` : autre site.
/// `prop` : proposition non sourcée, à valider par l'animateur ; jamais
/// présentée comme règle fédérale.
///
/// Type unique, partagé par le catalogue d'entraînement et les séances du
/// catalogue : les deux contenus ne peuvent pas diverger sur cette notion.
enum Provenance {
  s,
  ffb,
  web,
  prop;

  /// Vrai pour un élément `[Prop]`.
  bool get isProposal => this == Provenance.prop;
}
