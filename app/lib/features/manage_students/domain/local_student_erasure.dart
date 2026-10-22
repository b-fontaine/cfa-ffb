import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';

/// L'effacement d'un élève **sur l'appareil** (drift) : l'enchaînement
/// historique d'`EraseStudent`, en une unité de travail. Inchangé par FB8 ; il
/// n'y a ni reprise ni avancement (tout ou rien, instantané).
class LocalStudentErasure implements StudentErasure {
  LocalStudentErasure(this._erase, this._students);

  final EraseStudent _erase;
  final StudentRepository _students;

  @override
  Future<Result<ErasureStatus>> inspect(StudentId id) => runGuarded(() async {
    if (await _students.byId(id) == null) throw NotFound('student', id.value);
    return const ErasureStatus(
      preview: StudentPurgePreview(),
      inProgress: false,
    );
  });

  @override
  Future<Result<ErasureOutcome>> erase(
    StudentId id, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) async {
    switch (await _erase(id)) {
      case Ok():
        return const Ok(
          ErasureOutcome(
            status: OperationRunStatus.completed,
            doneLots: 1,
            totalLots: 1,
          ),
        );
      case Err(:final failure):
        return Err(failure);
    }
  }
}
