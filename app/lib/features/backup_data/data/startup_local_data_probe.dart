import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:injectable/injectable.dart';

/// Sonde de production : le relevé pris **au démarrage**, avant l'ouverture
/// de la base par l'application (`probeLocalStore`, `main.dart`). Après cette
/// ouverture, la base ne serait plus « telle qu'on l'a trouvée » (créée si
/// absente, migrée si ancienne).
@LazySingleton(as: LocalDataProbe, env: [Environment.prod])
class StartupLocalDataProbe implements LocalDataProbe {
  StartupLocalDataProbe(this._found);

  final LocalDataInventory _found;

  @override
  Future<LocalDataInventory> inspect() async => _found;
}
