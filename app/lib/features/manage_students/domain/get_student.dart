import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : lire un élève (édition de sa fiche).
@injectable
class GetStudent {
  GetStudent(this._students);

  final StudentRepository _students;

  Future<Result<Student>> call(StudentId studentId) => runGuarded(() async {
    final student = await _students.byId(studentId);
    if (student == null) throw NotFound('student', studentId.value);
    return student;
  });
}
