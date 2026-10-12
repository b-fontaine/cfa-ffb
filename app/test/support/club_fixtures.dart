import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Élève résumé : identifiant et prénom donnés, public enfants.
StudentSummary summary(String id, String firstName) => StudentSummary(
  student: Student.enroll(
    id: StudentId(id),
    firstName: firstName,
    audience: Audience.children,
    since: DateTime(2026, 9),
  ),
  validatedCount: 0,
  exerciseCount: 0,
  alertCount: 0,
);

/// Groupe de la saison `season` avec ses membres.
GroupOverview groupOverview(
  String id,
  String name,
  List<StudentSummary> members,
) => GroupOverview(
  group: Group(
    id: GroupId(id),
    seasonId: const SeasonId('season'),
    name: name,
    audience: Audience.children,
  ),
  members: members,
);
