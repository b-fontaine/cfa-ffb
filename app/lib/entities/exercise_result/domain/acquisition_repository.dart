import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux blocs acquis au positionnement (implémenté dans la couche
/// data).
///
/// [add] d'un id déjà connu remplace le marqueur (idempotent) ; la
/// suppression est logique.
abstract interface class AcquisitionRepository {
  Future<void> add(BlockAcquisition acquisition);

  /// Marqueurs de l'élève, du plus ancien au plus récent.
  Future<List<BlockAcquisition>> forStudent(StudentId studentId);

  /// Tous les marqueurs, dans l'ordre d'enregistrement.
  Future<List<BlockAcquisition>> all();

  /// Supprime logiquement le marqueur ; sans effet s'il n'existe pas.
  Future<void> delete(AcquisitionId id);

  /// Efface physiquement tous les marqueurs de l'élève (droit à
  /// l'effacement), y compris ceux supprimés logiquement.
  Future<void> eraseStudent(StudentId studentId);
}
