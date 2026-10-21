// Ce que la base locale (drift) de l'appareil contient, relevé **sans rien
// écrire** (lot FB7c, ADR 0024 notes FB7c).

/// État de la base locale de l'appareil au démarrage.
enum LocalStoreState {
  /// Aucune base locale : rien à exporter (et la détection n'en a pas créé).
  absent,

  /// Une base locale lisible, avec ses compteurs.
  present,

  /// Écrite par une version **plus récente** de l'application : on ne la lit
  /// pas (la lire ou l'ouvrir risquerait de l'altérer).
  newerSchema,

  /// Présente, mais la lecture a échoué (fichier abîmé, navigateur qui refuse
  /// l'accès) : jamais traitée comme « vide », l'utilisateur est averti.
  unreadable,
}

/// Compteurs du contenu saisi par l'animateur.
class LocalDataCounts {
  const LocalDataCounts({
    this.students = 0,
    this.groups = 0,
    this.seasons = 0,
    this.sessionRecords = 0,
    this.attempts = 0,
    this.plannedSessions = 0,
    this.assessments = 0,
    this.blockAcquisitions = 0,
    this.seasonArchives = 0,
  });

  static const zero = LocalDataCounts();

  final int students;
  final int groups;
  final int seasons;
  final int sessionRecords;
  final int attempts;
  final int plannedSessions;
  final int assessments;
  final int blockAcquisitions;

  /// Saisons closes dont il ne reste que l'archive agrégée (résultats
  /// d'élèves) : la seule trace de l'historique après une clôture.
  final int seasonArchives;

  /// Du contenu saisi existe. Les saisons et les réglages seuls ne comptent
  /// pas : une base sans élève, groupe, séance, passage, bilan, bloc acquis ni
  /// archive de saison n'a rien à protéger. **Définition unique** : le résumé
  /// d'un fichier (`ImportSummary.holdsNothing`) s'y réfère.
  bool get hasContent =>
      students > 0 ||
      groups > 0 ||
      sessionRecords > 0 ||
      attempts > 0 ||
      plannedSessions > 0 ||
      assessments > 0 ||
      blockAcquisitions > 0 ||
      seasonArchives > 0;
}

/// Le relevé de la base locale.
class LocalDataInventory {
  const LocalDataInventory({
    required this.state,
    this.schemaVersion,
    this.migrationPending = false,
    this.counts = LocalDataCounts.zero,
    this.lastModified,
  });

  /// Pas de base locale.
  static const none = LocalDataInventory(state: LocalStoreState.absent);

  final LocalStoreState state;

  /// Version du schéma trouvée dans la base (`null` si elle n'est pas lue).
  final int? schemaVersion;

  /// La base est plus **ancienne** que le schéma de l'application : son
  /// ouverture par l'application (qui sert aussi aux séances guidées en cours)
  /// la migre, de façon additive.
  final bool migrationPending;

  final LocalDataCounts counts;

  /// La **dernière modification réelle** des données : le plus récent des
  /// horodatages `updated_at` de la base (lignes effacées logiquement
  /// comprises), jamais l'heure de la lecture ni de l'export. `null` si la
  /// base ne porte aucun horodatage (base vide, ou non lue) : aucune date
  /// fiable n'existe alors (ADR 0019, ADR 0024 notes FB7c).
  final DateTime? lastModified;

  /// Les données de l'appareil peuvent être à protéger : du contenu connu, ou
  /// une base qu'on ne sait pas lire (jamais une perte silencieuse).
  bool get mayHoldData => switch (state) {
    LocalStoreState.absent => false,
    LocalStoreState.present => counts.hasContent,
    LocalStoreState.newerSchema || LocalStoreState.unreadable => true,
  };

  /// Les compteurs sont connus (base lue).
  bool get isReadable => state == LocalStoreState.present;
}
