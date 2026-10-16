import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : rétablir l'alerte d'un élève sur un exercice (ADR 0013).
///
/// Supprime logiquement tous les acquittements de l'élève pour cet exercice,
/// y compris les dormants : un « Vu » ultérieur en crée un nouveau. Tout ou
/// rien (unité de travail).
@injectable
class RestoreAlert {
  RestoreAlert(this._acknowledgements, this._unitOfWork);

  final AcknowledgementRepository _acknowledgements;
  final UnitOfWork _unitOfWork;

  Future<Result<void>> call({
    required StudentId studentId,
    required ExerciseRef exercise,
  }) => runGuarded(() async {
    await _unitOfWork.run(() async {
      final seen = [
        for (final acknowledgement in await _acknowledgements.forStudent(
          studentId,
        ))
          if (acknowledgement.exercise == exercise) acknowledgement,
      ];
      if (seen.isEmpty) {
        throw NotFound(
          'acknowledgement',
          '${exercise.blockId} ${exercise.number}',
        );
      }
      for (final acknowledgement in seen) {
        await _acknowledgements.delete(acknowledgement.id);
      }
    });
  });
}
