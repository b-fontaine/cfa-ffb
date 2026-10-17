import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/manage_club/domain/invitable_students.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les élèves que la personne connectée peut inviter (ou dont
/// elle peut inviter le parent), pour le formulaire d'invitation. Un
/// enseignant ne voit que les élèves de ses groupes.
@injectable
class ListInvitableStudents {
  ListInvitableStudents(
    this._students,
    this._groups,
    this._seasons,
    this._clock,
    this._scope,
    this._user,
  );

  final StudentRepository _students;
  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final Clock _clock;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<List<InvitableStudent>>> call() => runGuarded(() async {
    final session = requireClubSession(
      _scope,
      _user,
      capability: Capability.inviteFamilies,
    );
    final students = await invitableStudents(
      students: _students,
      groups: _groups,
      seasons: _seasons,
      today: _clock.today(),
      session: session,
    );
    return students;
  });
}
