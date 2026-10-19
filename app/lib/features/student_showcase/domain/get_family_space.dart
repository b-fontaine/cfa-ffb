import 'package:billard_cfa/entities/group/domain/group_names.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/student_showcase/domain/family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_student_showcase.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Combien de séances à venir l'espace montre au plus.
const familyUpcomingLimit = 5;

/// Cas d'usage : l'espace d'un parent ou d'un élève (FB6), en **lecture
/// seule**.
///
/// Ne lit que ce que les règles lui laissent : la fiche et le parcours de
/// **chaque élève lié** (jamais une liste d'élèves), les séances planifiées de
/// **ses** groupes et le nom de ces groupes. Ni saisies, ni bilans, ni
/// alertes, ni appartenances (liste des camarades) : ADR 0024, décision 26.
/// Une fiche liée qui n'existe pas (ou plus) est ignorée.
@injectable
class GetFamilySpace {
  GetFamilySpace(
    this._students,
    this._showcase,
    this._sessions,
    this._groupNames,
    this._scope,
    this._user,
    this._clock,
  );

  final StudentRepository _students;
  final GetStudentShowcase _showcase;
  final SessionRepository _sessions;
  final GroupNames _groupNames;
  final ActiveClubScope _scope;
  final CurrentUser _user;
  final Clock _clock;

  /// [linked] : les fiches que le lien du compte liste **encore** (`null` :
  /// toutes celles de la session). Une fiche déliée n'est pas relue : le
  /// serveur la refuserait, et l'espace entier passerait à tort en refus.
  Future<Result<FamilySpace>> call({Set<StudentId>? linked}) => runGuarded(
    () async {
      final session = requireClubSession(
        _scope,
        _user,
        capability: Capability.viewChildren,
      );
      final children = <FamilyChild>[];
      for (final id in session.studentIds) {
        if (linked != null && !linked.contains(id)) continue;
        final student = await _students.byId(id);
        if (student == null) continue;
        final showcase = switch (await _showcase(id)) {
          Ok(:final value) => value,
          Err(:final failure) => throw failure,
        };
        children.add(
          FamilyChild(id: id, firstName: student.firstName, showcase: showcase),
        );
      }
      final today = _clock.today();
      final names = await _groupNames.all();
      final planned = [
        for (final planned in await _sessions.getAll())
          if (!planned.date.isBefore(today)) planned,
      ]..sort((a, b) => a.date.compareTo(b.date));
      return FamilySpace(
        children: children,
        upcoming: [
          for (final planned in planned.take(familyUpcomingLimit))
            FamilySession(
              id: planned.id,
              title: planned.title,
              date: planned.date,
              audience: planned.audience,
              groupName: names[planned.groupId],
            ),
        ],
      );
    },
  );
}
