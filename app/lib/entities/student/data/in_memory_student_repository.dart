import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/change_feed.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: StudentRepository, env: [Environment.test])
class InMemoryStudentRepository implements StudentRepository {
  final ObservedMap<StudentId, Student> _students = ObservedMap();

  @override
  Future<void> save(Student student) async =>
      _students.journaledPut(student.id, student);

  @override
  Future<Student?> byId(StudentId id) async => _students[id];

  @override
  Future<List<Student>> all() async => _students.values.toList();

  @override
  Future<void> delete(StudentId id) async => _students.journaledRemove(id);

  @override
  Future<void> erase(StudentId id) async => _students.journaledRemove(id);

  @override
  Stream<Student?> watchById(StudentId id) => _students.watch(() => byId(id));

  @override
  Stream<List<Student>> watchAll() => _students.watch(all);
}
