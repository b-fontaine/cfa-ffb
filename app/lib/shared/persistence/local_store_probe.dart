import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:billard_cfa/shared/persistence/local_store_handle.dart';
import 'package:billard_cfa/shared/persistence/local_store_opener_web.dart'
    if (dart.library.io) 'package:billard_cfa/shared/persistence/local_store_opener_native.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Relève ce que contient la base locale de l'appareil **sans la créer, la
/// migrer ni y écrire** (lot FB7c).
///
/// À appeler **avant** l'ouverture de [AppDatabase] (qui crée une base absente
/// et migre une base ancienne) : voir `main.dart`. Les garanties, prouvées
/// par `local_store_probe_test.dart` :
///
/// - une base **absente** n'est pas créée (natif : aucun fichier ; web : la
///   sonde de drift liste OPFS et IndexedDB sans rien ouvrir) ;
/// - une base présente n'est ouverte qu'en **lecture seule** (natif :
///   `SQLITE_OPEN_READONLY`, web : connexion SQLite propre à la page, voir
///   `local_store_opener_web.dart`) et l'ouverture est **interrompue** avant
///   que drift n'écrive la version du schéma : une base plus ancienne ou plus
///   récente garde sa version ;
/// - la base est **libérée** avant le retour (aussi sur dépassement du délai) :
///   l'application l'ouvre ensuite comme si de rien n'était ;
/// - une base écrite par une version **plus récente** n'est pas lue ;
/// - toute erreur de lecture, ou une sonde qui n'aboutit pas en [timeout],
///   donne `unreadable`, jamais « vide ».
///
/// Limite web : la détection charge les mêmes fichiers WebAssembly que
/// l'application. Si le navigateur ne laisse pas lire la base (stockage
/// bloqué), le relevé est `unreadable` et l'animateur est averti. Prouvée par
/// `scripts/local_data_web.sh` (Chrome réel), pas seulement par les tests Dart.
Future<LocalDataInventory> probeLocalStore(
  DatabaseSettings settings, {
  int appSchemaVersion = AppDatabase.currentSchemaVersion,
  Duration timeout = const Duration(seconds: 10),
  @visibleForTesting
  Future<LocalStoreHandle?> Function(DatabaseSettings) open =
      openExistingLocalStore,
}) async {
  LocalStoreHandle? handle;
  var abandoned = false;
  Future<LocalDataInventory> run() async {
    final opened = await open(settings);
    if (opened == null) return LocalDataInventory.none;
    handle = opened;
    // Le délai est passé pendant l'ouverture : personne n'attend plus ce
    // relevé, et la base ne doit pas rester tenue.
    if (abandoned) {
      await opened.release();
      return const LocalDataInventory(state: LocalStoreState.unreadable);
    }
    return await inspectLocalStore(opened, appSchemaVersion);
  }

  try {
    // Sans délai, une base tenue par un autre onglet (verrou exclusif) ferait
    // attendre la sonde sans fin, avant même `runApp` : écran blanc.
    return await run().timeout(timeout);
  } on Object {
    abandoned = true;
    return const LocalDataInventory(state: LocalStoreState.unreadable);
  } finally {
    // Dépassement du délai ou erreur : aucun exécuteur, aucun verrou laissé.
    await handle?.release();
  }
}

/// Relevé d'une base **déjà ouverte** ; ferme l'exécuteur et libère la base.
Future<LocalDataInventory> inspectLocalStore(
  LocalStoreHandle store,
  int appSchemaVersion,
) async {
  final user = _InventoryUser(
    appSchemaVersion,
    readOnly: store.privateConnection,
  );
  try {
    await store.executor.ensureOpen(user);
  } on Object {
    // L'ouverture est interrompue exprès (voir `beforeOpen`). Sur le web, et
    // pour toute connexion distante, drift enveloppe l'exception en
    // `DriftRemoteException` : son type est perdu. Le relevé fait foi, quel
    // que soit le type de l'erreur ; sans relevé, la base est illisible.
  }
  await store.release();
  return user.result ??
      const LocalDataInventory(state: LocalStoreState.unreadable);
}

class _InventoryDone implements Exception {
  const _InventoryDone();
}

/// L'« utilisateur » de l'exécuteur : lit la version et les compteurs dans
/// `beforeOpen`, puis **lève** pour que drift n'écrive jamais la version du
/// schéma (il ne le fait qu'après le retour de `beforeOpen`).
class _InventoryUser implements QueryExecutorUser {
  _InventoryUser(this.schemaVersion, {required this.readOnly});

  @override
  final int schemaVersion;

  /// La connexion est à la détection seule : `query_only` en plus de
  /// l'ouverture en lecture seule. Jamais sur une connexion partagée.
  final bool readOnly;

  LocalDataInventory? result;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    // Le prétendu « ouvert » de l'exécuteur de `beforeOpen` : il ne bloque
    // pas, et sans lui drift refuse les requêtes.
    await executor.ensureOpen(this);
    if (readOnly) await executor.runCustom('PRAGMA query_only = ON');
    final found = details.versionBefore;
    if (found == null) {
      // Fichier présent mais jamais initialisé par l'application.
      result = const LocalDataInventory(state: LocalStoreState.present);
    } else if (found > schemaVersion) {
      result = LocalDataInventory(
        state: LocalStoreState.newerSchema,
        schemaVersion: found,
      );
    } else {
      result = LocalDataInventory(
        state: LocalStoreState.present,
        schemaVersion: found,
        migrationPending: found < schemaVersion,
        counts: await _count(executor),
        lastModified: await _lastModified(executor),
      );
    }
    throw const _InventoryDone();
  }

  /// Le plus récent des `updated_at` (lignes effacées logiquement comprises).
  /// Les horodatages sont des textes ISO 8601 : on les compare comme dates.
  Future<DateTime?> _lastModified(QueryExecutor executor) async {
    DateTime? latest;
    for (final table in const [
      'students',
      'seasons',
      'groups',
      'session_records',
      'attempts',
      'assessments',
      'planned_sessions',
      'block_acquisitions',
      'alert_acknowledgements',
    ]) {
      final columns = await executor.runSelect(
        'PRAGMA table_info("$table")',
        const [],
      );
      if (!columns.any((c) => c['name'] == 'updated_at')) continue;
      final rows = await executor.runSelect(
        'SELECT updated_at FROM "$table" ORDER BY updated_at DESC '
        'LIMIT 1',
        const [],
      );
      if (rows.isEmpty) continue;
      final at = DateTime.tryParse('${rows.first['updated_at']}');
      if (at != null && (latest == null || at.isAfter(latest))) latest = at;
    }
    return latest;
  }

  Future<LocalDataCounts> _count(QueryExecutor executor) async {
    Future<int> rows(String table) async {
      final columns = await executor.runSelect(
        'PRAGMA table_info("$table")',
        const [],
      );
      if (columns.isEmpty) return 0;
      final soft = columns.any((c) => c['name'] == 'deleted_at');
      final result = await executor.runSelect(
        'SELECT COUNT(*) AS n FROM "$table"'
        '${soft ? ' WHERE deleted_at IS NULL' : ''}',
        const [],
      );
      return result.first['n']! as int;
    }

    // Archives : une par saison présente dans l'une des deux tables.
    Future<int> archives() async {
      for (final table in const [
        'season_archive_audiences',
        'season_archive_exercises',
      ]) {
        final columns = await executor.runSelect(
          'PRAGMA table_info("$table")',
          const [],
        );
        if (columns.isEmpty) return 0;
      }
      final result = await executor.runSelect(
        'SELECT COUNT(*) AS n FROM (SELECT season_id FROM '
        'season_archive_audiences UNION SELECT season_id FROM '
        'season_archive_exercises)',
        const [],
      );
      return result.first['n']! as int;
    }

    return LocalDataCounts(
      seasonArchives: await archives(),
      students: await rows('students'),
      groups: await rows('groups'),
      seasons: await rows('seasons'),
      sessionRecords: await rows('session_records'),
      attempts: await rows('attempts'),
      plannedSessions: await rows('planned_sessions'),
      assessments: await rows('assessments'),
      blockAcquisitions: await rows('block_acquisitions'),
    );
  }
}
