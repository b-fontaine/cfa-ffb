import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/manage_groups/domain/move_options.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : le groupe actuel d'un élève et les groupes où il peut être
/// déplacé (même saison ouverte, même public). Un élève sans groupe se place
/// dans un groupe de la saison ouverte de son public.
@injectable
class GetMoveOptions {
  GetMoveOptions(this._students, this._groups, this._seasons);

  final StudentRepository _students;
  final GroupRepository _groups;
  final SeasonRepository _seasons;

  Future<Result<MoveOptions>> call({
    required StudentId studentId,
    required DateTime today,
  }) => runGuarded(() async {
    final student = await _students.byId(studentId);
    if (student == null) throw NotFound('student', studentId.value);
    final seasons = await _seasons.all();
    final closed = {
      for (final s in seasons)
        if (s.isClosed) s.id,
    };
    final open = {
      for (final s in seasons)
        if (s.isOpenOn(today)) s.id,
    };
    final groups = await _groups.all();
    Group? current;
    for (final group in groups) {
      if (!closed.contains(group.seasonId) &&
          group.memberships.any(
            (m) => m.studentId == studentId && m.to == null,
          )) {
        current = group;
        break;
      }
    }
    final seasonIds = current == null ? open : {current.seasonId};
    final audience = current?.audience ?? student.currentAudience;
    return MoveOptions(
      studentId: studentId,
      firstName: student.firstName,
      current: current == null ? null : GroupChoice(current.id, current.name),
      destinations: [
        for (final group in groups)
          if (seasonIds.contains(group.seasonId) &&
              group.audience == audience &&
              group.id != current?.id)
            GroupChoice(group.id, group.name),
      ],
    );
  });
}
