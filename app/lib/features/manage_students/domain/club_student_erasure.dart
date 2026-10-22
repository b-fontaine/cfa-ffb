import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/features/manage_students/domain/student_erasure_operation.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';

/// L'effacement d'un élève dans un **club synchronisé** : l'opération
/// reprenable de FB8 (`StudentErasureOperation`) menée par `OperationRunner`.
/// Réservé aux rôles de la capacité `eraseStudent` (ADR 0024, matrice :
/// l'enseignant ne supprime pas une fiche) ; refus avant toute écriture sinon.
class ClubStudentErasure implements StudentErasure {
  ClubStudentErasure(this._runner, this._purge, this._scope);

  final OperationRunner _runner;
  final StudentPurge _purge;
  final ActiveClubScope _scope;

  /// Le rôle courant s'il a la capacité d'effacer (`RolePolicy`, source unique
  /// de la matrice : l'écran et ce cas d'usage ne peuvent pas diverger).
  Role? get _manager {
    final role = _scope.role;
    return role != null && role.can(Capability.eraseStudent) ? role : null;
  }

  @override
  Future<Result<ErasureStatus>> inspect(StudentId id) => runGuarded(() async {
    if (_manager == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'role');
    }
    if (!await _purge.exists(id)) throw NotFound('student', id.value);
    return ErasureStatus(
      preview: await _purge.preview(id),
      inProgress: (await _purge.flagged()).contains(id),
      synchronized: true,
    );
  });

  @override
  Future<Result<ErasureOutcome>> erase(
    StudentId id, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) => runGuarded(() async {
    final role = _manager;
    final club = _scope.clubId;
    if (role == null || club == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'role');
    }
    // Même sans fiche, le moteur est appelé : s'il trouve le marqueur de cet
    // effacement (une clôture a absorbé la fiche, ou un autre appareil l'a
    // terminée), il le retire ; sans marqueur, il n'y a rien à effacer.
    final result = await _runner(
      StudentErasureOperation(_purge, id, club),
      role: role,
      shouldStop: shouldStop,
      onProgress: onProgress,
    );
    switch (result) {
      case Ok(:final value):
        if (value.alreadyDone) throw NotFound('student', id.value);
        return ErasureOutcome(
          status: value.status,
          doneLots: value.doneLots,
          totalLots: value.totalLots,
          failure: value.failure,
        );
      case Err(:final failure):
        throw failure;
    }
  });
}
