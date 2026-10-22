import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';

/// Le compte du jour des écritures **de cet appareil**, partagé entre l'import
/// d'une sauvegarde et les opérations reprenables (effacement, clôture) : un
/// seul compteur, pour que leur somme reste sous le quota quotidien du plan
/// Spark.
final class ImportDailyLedgerAdapter implements DailyWriteLedger {
  const ImportDailyLedgerAdapter(this._ledger);

  final ImportDailyLedger _ledger;

  @override
  Future<int> spentToday() => _ledger.spentToday();

  @override
  Future<void> add(int writes) => _ledger.add(writes);
}
