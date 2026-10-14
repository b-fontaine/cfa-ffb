import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : retirer l'acquis d'un bloc (suppression logique du marqueur,
/// ADR 0008). Le bloc peut être marqué de nouveau ensuite. Tout ou rien
/// (unité de travail) : des données importées peuvent porter plusieurs
/// marqueurs.
@injectable
class RevokeBlockAcquired {
  RevokeBlockAcquired(this._acquisitions, this._unitOfWork);

  final AcquisitionRepository _acquisitions;
  final UnitOfWork _unitOfWork;

  Future<Result<void>> call({
    required StudentId studentId,
    required String blockId,
  }) => runGuarded(() async {
    await _unitOfWork.run(() async {
      final marked = (await _acquisitions.forStudent(studentId))
          .where((a) => a.blockId == blockId)
          .toList();
      if (marked.isEmpty) throw NotFound('acquisition', blockId);
      for (final acquisition in marked) {
        await _acquisitions.delete(acquisition.id);
      }
    });
  });
}
