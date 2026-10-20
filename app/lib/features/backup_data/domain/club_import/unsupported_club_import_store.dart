import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/failure.dart';

/// Le club vu par l'import quand les données **ne sont pas** dans Firestore
/// (`DATA_BACKEND=drift`, le défaut) : toutes les lectures de l'application
/// vont à drift, un import qui écrirait dans Firestore créerait des données que
/// l'application ne relirait pas. Chaque appel est donc refusé
/// (`ServiceFailure` `unsupported`), sans rien lire ni écrire (ADR 0024,
/// décision 28 : l'aiguillage est celui de `DataBackendModule`).
final class UnsupportedClubImportStore implements ClubImportStore {
  const UnsupportedClubImportStore();

  static const _failure = ServiceFailure(
    ServiceFailureCode.unsupported,
    'club import needs DATA_BACKEND=firestore',
  );

  @override
  Future<ClubInventory> inventory(String fileId) => Future.error(_failure);

  @override
  Future<ImportMarker?> readMarker(String fileId) => Future.error(_failure);

  @override
  Future<void> commit(ImportLotCommit commit) => Future.error(_failure);
}
