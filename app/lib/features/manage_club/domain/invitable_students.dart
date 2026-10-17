import 'package:billard_cfa/entities/group/domain/current_groups.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';

/// Un élève que la personne connectée peut inviter (ou dont elle peut inviter
/// le parent) et ses groupes du jour qu'elle voit.
class InvitableStudent {
  const InvitableStudent({required this.student, required this.groups});

  final Student student;

  /// Groupes courants de l'élève visibles de l'invitant : tous pour le
  /// directeur et l'administrateur, **les siens seulement** pour un enseignant.
  final List<Group> groups;
}

/// Les élèves invitables, triés par prénom : ceux qui ont un groupe courant
/// (saison ouverte à [today]) visible de [session]. Un enseignant ne voit que
/// ses groupes (`session.groupIds`) : un élève d'un autre groupe n'est pas
/// proposé.
Future<List<InvitableStudent>> invitableStudents({
  required StudentRepository students,
  required GroupRepository groups,
  required SeasonRepository seasons,
  required DateTime today,
  required ClubSession session,
}) async {
  final all = await seasons.all();
  final current = currentGroups(
    await groups.all(),
    currentSeasons: {
      for (final season in all)
        if (season.isOpenOn(today)) season.id,
    },
    closedSeasons: {
      for (final season in all)
        if (season.isClosed) season.id,
    },
  );
  final visible = session.role == Role.teacher
      ? [
          for (final group in current)
            if (session.groupIds.contains(group.id)) group,
        ]
      : current;
  final result = <InvitableStudent>[
    for (final student in await students.all())
      if ([
            for (final group in visible)
              if (group.isMemberOn(student.id, today)) group,
          ]
          case final theirs when theirs.isNotEmpty)
        InvitableStudent(student: student, groups: theirs),
  ]..sort((a, b) => a.student.firstName.compareTo(b.student.firstName));
  return result;
}
