/// Mode du guide : « Mener » pour conduire la séance devant les élèves,
/// « Relecture » pour la relire en entier et valider les propositions
/// (décision Q4).
enum RunMode {
  /// Séance menée : provenance `[Prop]` masquée, sections « pour aller plus
  /// loin » repliées.
  lead,

  /// Séance relue : provenance affichée, tout est déplié.
  review;

  /// Mode d'ouverture d'un guide : « Mener » quand il est lancé depuis une
  /// séance [planned] (planifiée), « Relecture » sinon (détail, lien direct).
  factory RunMode.defaultFor({required bool planned}) =>
      planned ? lead : review;

  /// Vrai quand les badges de provenance sont affichés. En « Mener » ils sont
  /// masqués, mais la donnée (`Provenance.prop`) et son accès (relecture,
  /// sémantique) restent.
  bool get showsProvenance => this == review;

  /// Vrai quand les sections repliables sont dépliées d'office.
  bool get expandsSections => this == review;

  /// Le mode d'une valeur d'adresse (`?mode=`), `null` si elle est absente ou
  /// inconnue (jamais une valeur libre).
  static RunMode? tryParse(String? raw) {
    for (final mode in values) {
      if (mode.name == raw) return mode;
    }
    return null;
  }
}
