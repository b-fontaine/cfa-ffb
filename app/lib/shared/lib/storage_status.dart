import 'package:injectable/injectable.dart';

/// Implémentation de stockage réellement retenue à l'ouverture de la base.
///
/// Sur le web, le navigateur peut ne pas offrir de stockage persistant : la
/// base retombe alors en mémoire et les données sont perdues à la fermeture ;
/// l'interface doit l'indiquer et proposer l'export JSON.
enum StorageImplementation {
  /// Fichier SQLite natif (Android, iOS, macOS, Windows, Linux).
  nativeFile(persistent: true),

  /// Web : origin private file system (le plus fiable).
  webOpfs(persistent: true),

  /// Web : IndexedDB (repli persistant).
  webIndexedDb(persistent: true),

  /// Pas de persistance : base en mémoire (tests, navigateur sans stockage).
  inMemory(persistent: false);

  StorageImplementation({required this.persistent});

  /// Vrai si les données survivent à la fermeture de l'application.
  final bool persistent;
}

/// État du stockage (port du domaine, implémenté par la couche de données).
abstract interface class StorageStatus {
  StorageImplementation get implementation;

  /// Raisons pour lesquelles une implémentation moins fiable a été retenue
  /// (fonctionnalités du navigateur manquantes) ; vide si aucune.
  List<String> get degradationReasons;
}

/// État de stockage des tests et scénarios BDD : persistant par défaut, et
/// modifiable pour simuler un navigateur sans stockage durable.
@LazySingleton(as: StorageStatus, env: [Environment.test])
class InMemoryStorageStatus implements StorageStatus {
  @override
  StorageImplementation implementation = StorageImplementation.nativeFile;

  @override
  List<String> degradationReasons = const [];
}
