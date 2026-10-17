import 'package:billard_cfa/entities/student/domain/student_directory.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';
import 'package:injectable/injectable.dart';

/// Annuaire des fiches d'élèves dans le stock de documents.
@LazySingleton(as: StudentDirectory)
class StoreStudentDirectory implements StudentDirectory {
  StoreStudentDirectory(this._store);

  final DocumentStore _store;

  static String pathOf(ClubId club, StudentId student) =>
      'clubs/${club.value}/students/${student.value}';

  @override
  Future<void> publish(ClubId club, List<PublishedStudent> students) =>
      guardStore(() async {
        final writes = <WriteOp>[];
        for (final student in students) {
          final path = pathOf(club, student.id);
          if (await _store.get(path) != null) continue;
          final name = student.firstName.trim();
          writes.add(
            SetOp(path, {
              // Les règles refusent un prénom de plus de 40 caractères : on
              // tronque plutôt que de bloquer l'invitation.
              'firstName': name.length > maxFirstNameLength
                  ? name.substring(0, maxFirstNameLength)
                  : name,
              'audience': student.audience.name,
              'groupIds': [for (final id in student.groupIds) id.value],
              'createdAt': serverTimestamp,
            }),
          );
        }
        if (writes.isNotEmpty) await _store.commit(writes);
      });
}
