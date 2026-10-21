import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:injectable/injectable.dart';

/// Sonde des tests et scénarios BDD : le relevé est celui que la scène pose.
@LazySingleton(as: LocalDataProbe, env: [Environment.test])
class InMemoryLocalDataProbe implements LocalDataProbe {
  /// Le relevé rendu par [inspect].
  LocalDataInventory inventory = LocalDataInventory.none;

  @override
  Future<LocalDataInventory> inspect() async => inventory;
}
