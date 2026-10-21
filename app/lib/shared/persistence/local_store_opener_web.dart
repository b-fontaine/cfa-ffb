import 'package:billard_cfa/shared/persistence/local_store_handle.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// Nom de la couche de fichiers de la sonde : distinct de celui de
/// l'application, jamais confondu avec lui dans la page.
const _probeVfsName = 'billard-cfa-local-data-probe';

/// La base du navigateur **si elle existe**, `null` sinon. La sonde de drift
/// liste les bases d'OPFS et d'IndexedDB sans en créer aucune.
///
/// **IndexedDB** (le stockage de la production : le site n'est pas isolé
/// entre origines, drift n'y choisit pas OPFS) : la base est lue **dans la
/// page**, par une connexion SQLite à elle, en lecture seule, **sans passer par
/// le serveur partagé de drift**. Ce serveur est unique par nom de base et
/// vit tant qu'un client reste connecté : y passer rendait la sonde aveugle
/// (l'ouverture est déjà faite, `beforeOpen` ne s'exécute plus) dès qu'un
/// ancien onglet de l'application était resté ouvert, et laissait la base
/// ouverte pendant que l'application démarrait.
///
/// **OPFS seul** (navigateur isolé entre origines) : la base n'est lisible que
/// depuis un worker ; la lecture passe par le worker de drift. Limite
/// assumée : si ce worker tient déjà la base, le relevé est « illisible » et
/// l'animateur est averti.
Future<LocalStoreHandle?> openExistingLocalStore(
  DatabaseSettings settings,
) async {
  final probe = await WasmDatabase.probe(
    sqlite3Uri: Uri.parse(sqlite3WasmPath),
    driftWorkerUri: Uri.parse(driftWorkerPath),
    databaseName: appDatabaseName,
  );
  final storages = {
    for (final (api, name) in probe.existingDatabases)
      if (name == appDatabaseName) api,
  };
  if (storages.isEmpty) return null;
  if (storages.contains(WebStorageApi.indexedDb)) {
    return await _readIndexedDbInPage();
  }
  final candidates =
      probe.availableStorages
          .where((s) => storages.contains(s.storageApi))
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));
  // Une base existe mais le navigateur ne sait pas l'ouvrir : illisible.
  if (candidates.isEmpty) throw StateError('stockage indisponible');
  final connection = await probe.open(candidates.first, appDatabaseName);
  return LocalStoreHandle(connection.executor, privateConnection: false);
}

Future<LocalStoreHandle> _readIndexedDbInPage() async {
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse(sqlite3WasmPath));
  final fileSystem = await IndexedDbFileSystem.open(
    dbName: appDatabaseName,
    vfsName: _probeVfsName,
    // Rien n'est jamais écrit : aucune écriture IndexedDB n'est planifiée.
    writeAutomatically: false,
  );
  try {
    sqlite3.registerVirtualFileSystem(fileSystem);
    final database = sqlite3.open(
      '/database',
      vfs: _probeVfsName,
      mode: OpenMode.readOnly,
    );
    return LocalStoreHandle(
      WasmDatabase.opened(database),
      onRelease: fileSystem.close,
    );
  } on Object {
    await fileSystem.close();
    rethrow;
  }
}
