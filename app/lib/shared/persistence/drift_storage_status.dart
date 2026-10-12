import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// État du stockage observé à l'ouverture de la base drift.
///
/// En natif, l'implémentation est toujours un fichier SQLite. Sur le web,
/// drift choisit au chargement entre OPFS, IndexedDB et la mémoire selon les
/// fonctionnalités du navigateur (`chosenImplementation`) : [recordWebResult]
/// le consigne pour que l'interface puisse avertir l'utilisateur.
class DriftStorageStatus implements StorageStatus {
  StorageImplementation _implementation = StorageImplementation.nativeFile;
  List<String> _reasons = const [];

  @override
  StorageImplementation get implementation => _implementation;

  @override
  List<String> get degradationReasons => _reasons;

  /// Consigne le résultat du choix d'implémentation côté navigateur.
  void recordWebResult(WasmDatabaseResult result) {
    _implementation = storageImplementationOf(result.chosenImplementation);
    _reasons = [for (final f in result.missingFeatures) f.name];
  }

  /// Traduit le choix de drift dans le vocabulaire du domaine.
  static StorageImplementation storageImplementationOf(
    WasmStorageImplementation chosen,
  ) => switch (chosen) {
    WasmStorageImplementation.opfsShared ||
    WasmStorageImplementation.opfsLocks => StorageImplementation.webOpfs,
    WasmStorageImplementation.sharedIndexedDb ||
    WasmStorageImplementation.unsafeIndexedDb =>
      StorageImplementation.webIndexedDb,
    WasmStorageImplementation.inMemory => StorageImplementation.inMemory,
  };
}
