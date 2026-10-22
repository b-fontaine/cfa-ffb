import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';

/// Où en est l'effacement d'un élève : ce qu'il supprimera, et s'il est déjà
/// commencé (fiche marquée `erasing` : à reprendre).
final class ErasureStatus {
  const ErasureStatus({
    required this.preview,
    required this.inProgress,
    this.synchronized = false,
  });

  final StudentPurgePreview preview;

  /// Un effacement de cet élève est commencé et n'est pas terminé.
  final bool inProgress;

  /// Les données sont dans le club : effacement par lots reprenables.
  final bool synchronized;
}

/// Le résultat d'une exécution d'effacement, pour l'écran.
final class ErasureOutcome {
  const ErasureOutcome({
    required this.status,
    this.doneLots = 0,
    this.totalLots = 0,
    this.failure,
  });

  final OperationRunStatus status;
  final int doneLots;
  final int totalLots;
  final ServiceFailure? failure;

  bool get completed => status == OperationRunStatus.completed;
}

/// Port de l'écran d'effacement : **commencer ou reprendre** l'effacement d'un
/// élève. Deux réalisations : `LocalStudentErasure` (drift, une unité de
/// travail) et `ClubStudentErasure` (club synchronisé, lots reprenables).
abstract interface class StudentErasure {
  /// Ce que l'effacement supprimera et s'il est déjà commencé.
  Future<Result<ErasureStatus>> inspect(StudentId id);

  /// Efface (ou reprend) : rend la main **entre deux lots** quand [shouldStop]
  /// devient vrai. [onProgress] reçoit les lots faits sur les lots prévus.
  Future<Result<ErasureOutcome>> erase(
    StudentId id, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  });
}
