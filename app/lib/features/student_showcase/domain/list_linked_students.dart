import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les élèves liés au compte (élève : sa fiche ; parent : ses
/// enfants), dans l'ordre du lien. Une fiche liée qui n'existe pas sur cet
/// appareil est ignorée (les données de groupe ne sont lues du serveur qu'au
/// lot FB4). Réservé aux comptes qui voient leur propre parcours.
@injectable
class ListLinkedStudents {
  ListLinkedStudents(this._students, this._scope, this._user);

  final StudentRepository _students;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<List<Student>>> call() => runGuarded(() async {
    final session = requireClubSession(
      _scope,
      _user,
      capability: Capability.viewChildren,
    );
    final students = <Student>[];
    for (final id in session.studentIds) {
      final student = await _students.byId(id);
      if (student != null) students.add(student);
    }
    return students;
  });
}
