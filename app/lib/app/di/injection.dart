import 'package:billard_cfa/app/di/injection.config.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

final GetIt getIt = GetIt.instance;

/// Compose le graphe de dépendances.
///
/// [environment] : `prod` (SQLite drift, identifiants UUID) ou `test`
/// (dépôts en mémoire, identifiants séquentiels). [settings] : emplacement de
/// la base en production (surchargé par les tests d'intégration).
@InjectableInit(ignoreUnregisteredTypes: [DatabaseSettings])
Future<void> configureDependencies({
  String environment = Environment.prod,
  DatabaseSettings settings = const DatabaseSettings(),
}) async {
  getIt.registerSingleton<DatabaseSettings>(settings);
  await getIt.init(environment: environment);
}
