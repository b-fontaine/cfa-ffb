import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';

const _failure = ServiceFailure(
  ServiceFailureCode.unsupported,
  'resumable operations need DATA_BACKEND=firestore',
);

/// Le magasin d'opérations quand les données **ne sont pas** dans Firestore
/// (`DATA_BACKEND=drift`, explicite) : l'effacement et la clôture restent
/// ceux de l'appareil (une unité de travail), et rien n'appelle ce magasin.
/// Chaque appel est refusé (`unsupported`) sans rien lire ni écrire.
final class UnsupportedOperationStore implements OperationStore {
  const UnsupportedOperationStore();

  @override
  Future<OperationMarker?> readMarker(String key) => Future.error(_failure);

  @override
  Future<List<OperationMarker>> ownMarkers() => Future.error(_failure);

  @override
  Future<void> commit(OperationLotCommit commit) => Future.error(_failure);
}

/// La purge d'un élève quand les données ne sont pas dans Firestore : refusée
/// (`unsupported`), comme [UnsupportedOperationStore].
final class UnsupportedStudentPurge implements StudentPurge {
  const UnsupportedStudentPurge();

  @override
  Future<StudentPurgePreview> preview(StudentId id) => Future.error(_failure);

  @override
  Future<bool> exists(StudentId id) => Future.error(_failure);

  @override
  Future<Set<StudentId>> flagged() => Future.error(_failure);

  @override
  OperationLot flag(Set<StudentId> ids) => throw _failure;

  @override
  Future<List<OperationLot>> purgeLots(
    Set<StudentId> ids, {
    required int maxWrites,
  }) => Future.error(_failure);

  @override
  OperationLot removeRecords(Set<StudentId> ids) => throw _failure;
}
