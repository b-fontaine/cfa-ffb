/// Où vivent les données d'un club : l'appareil (drift) ou Firestore.
///
/// Réglage de **build** : `--dart-define=DATA_BACKEND=drift|firestore`. Sans
/// réglage (ou `firestore`), les données du club vivent sur Firestore : lot de
/// bascule du 2026-10-21 (ADR 0024, décision 28 amendée). `drift` reste
/// sélectionnable **explicitement** (développement, build qui remplit une base
/// locale, prévisualisations de pull request). Une valeur inconnue est une
/// erreur de configuration, pas un repli silencieux sur l'un des deux (un club
/// qui croit écrire sur le serveur écrirait sur l'appareil).
enum DataBackend {
  drift,
  firestore;

  /// Le réglage du build en cours.
  factory DataBackend.fromBuild() =>
      DataBackend.resolve(const String.fromEnvironment('DATA_BACKEND'));

  /// Le choix pour la valeur [requested] du réglage (vide : firestore).
  factory DataBackend.resolve(String requested) {
    final value = requested.trim().toLowerCase();
    if (value.isEmpty) return DataBackend.firestore;
    for (final backend in DataBackend.values) {
      if (backend.name == value) return backend;
    }
    throw DataBackendError(
      'DATA_BACKEND="$requested" inconnu : "drift" ou "firestore".',
    );
  }

  /// La réalisation à utiliser : [drift] ou [firestore], construite à la
  /// demande (l'autre n'est jamais créée).
  T choose<T>({required T Function() drift, required T Function() firestore}) =>
      switch (this) {
        DataBackend.drift => drift(),
        DataBackend.firestore => firestore(),
      };
}

/// Réglage de backend invalide.
class DataBackendError extends Error {
  DataBackendError(this.message);

  final String message;

  @override
  String toString() => 'DataBackendError: $message';
}

/// Le backend retenu pour le processus, enregistré dans l'injection (un
/// `enum` ne s'y enregistre pas).
final class DataBackendChoice {
  const DataBackendChoice(this.backend);

  final DataBackend backend;
}

/// La demande de backend faite à l'injection : [backend] explicite (tests du
/// graphe de production), sinon le réglage du build ([DataBackend.fromBuild]).
final class DataBackendRequest {
  const DataBackendRequest([this.backend]);

  final DataBackend? backend;

  DataBackend get resolved => backend ?? DataBackend.fromBuild();
}
