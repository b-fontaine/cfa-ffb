import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : corriger le prénom d'un élève (le public ne change que par
/// `ChangeAudience`, toujours manuellement).
@injectable
class RenameStudent {
  RenameStudent(this._students);

  final StudentRepository _students;

  Future<Result<Student>> call({
    required StudentId studentId,
    required String firstName,
  }) => runGuarded(() async {
    if (firstName.trim().length > maxFirstNameLength) {
      throw const InvariantViolation(InvariantCode.nameTooLong);
    }
    final student = await _students.byId(studentId);
    if (student == null) throw NotFound('student', studentId.value);
    final renamed = Student(
      id: student.id,
      firstName: firstName.trim(),
      audienceHistory: student.audienceHistory,
    );
    await _students.save(renamed);
    return renamed;
  });
}
