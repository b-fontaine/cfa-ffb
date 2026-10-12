import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:billard_cfa/shared/persistence/drift_storage_status.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Nom de la base : fichier `billard_cfa.sqlite` en natif, base du navigateur
/// sur le web.
const appDatabaseName = 'billard_cfa';

/// Réglages d'ouverture de la base (surchargeables dans les tests).
class DatabaseSettings {
  const DatabaseSettings({this.native});

  /// Emplacement du fichier natif ; `null` = dossier de documents de l'app.
  final DriftNativeOptions? native;
}

/// Ouvre la base : fichier SQLite natif (Android, iOS, macOS, Windows, Linux)
/// ou WebAssembly sur le web (`sqlite3.wasm` et `drift_worker.js` servis depuis
/// `web/`, à la version de drift ; voir `scripts/sync_web_assets.sh`).
///
/// L'ouverture est paresseuse : [status] n'est renseigné sur le web qu'après la
/// première requête (voir `PersistenceModule`).
AppDatabase openAppDatabase({
  required DriftStorageStatus status,
  DatabaseSettings settings = const DatabaseSettings(),
}) => AppDatabase(
  driftDatabase(
    name: appDatabaseName,
    native: settings.native,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
      onResult: status.recordWebResult,
    ),
  ),
);
