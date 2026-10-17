import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_code_source.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_directory.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/manage_club/domain/invitable_students.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : créer une invitation à usage unique dans le club actif
/// (ADR 0024, décisions 6 et 24).
///
/// - **enseignant** (directeur ou administrateur seulement) : avec ses
///   groupes, valable 48 heures ;
/// - **élève** (une seule fiche, case « a 15 ans ou plus » obligatoire) ou
///   **parent** (une à quatre fiches) : l'invitant choisit parmi les élèves
///   qu'il voit (un enseignant : ceux de ses groupes) ; les groupes de
///   l'invitation sont ceux de ces élèves ; valable 7 jours ;
/// - un directeur n'est jamais invité d'ici : c'est « Administration ».
///
/// Avant de créer l'invitation, la fiche minimale de chaque élève lié est
/// **publiée** côté serveur si elle n'y est pas (`StudentDirectory`) : les
/// règles exigent que la fiche existe. L'invitation est ensuite créée et son
/// code retenu sur l'appareil (le serveur ne liste jamais les invitations).
@injectable
class IssueInvitation {
  IssueInvitation(
    this._invitations,
    this._directory,
    this._codes,
    this._issued,
    this._students,
    this._groups,
    this._seasons,
    this._clock,
    this._scope,
    this._user,
  );

  final InvitationRepository _invitations;
  final StudentDirectory _directory;
  final InvitationCodeSource _codes;
  final IssuedInvitations _issued;
  final StudentRepository _students;
  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final Clock _clock;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<Invitation>> call({
    required Role role,
    Set<GroupId> groupIds = const {},
    Set<StudentId> studentIds = const {},
    bool ageConfirmed = false,
  }) => runGuarded(() async {
    final session = requireClubSession(_scope, _user);
    if (role == Role.director ||
        role == Role.admin ||
        !InvitationPolicy.canIssue(session.role, role)) {
      throw const InvariantViolation(InvariantCode.actionNotAllowed);
    }
    var groups = [...groupIds];
    final published = <PublishedStudent>[];
    if (role == Role.student || role == Role.guardian) {
      if (role == Role.student && !ageConfirmed) {
        throw const InvariantViolation(InvariantCode.ageConfirmationRequired);
      }
      final tooMany = studentIds.length > InvitationPolicy.maxChildren;
      if (studentIds.isEmpty ||
          tooMany ||
          (role == Role.student && studentIds.length != 1)) {
        throw const InvariantViolation(InvariantCode.studentChoiceRequired);
      }
      final invitable = await invitableStudents(
        students: _students,
        groups: _groups,
        seasons: _seasons,
        today: _clock.today(),
        session: session,
      );
      groups = [];
      for (final id in studentIds) {
        final found = invitable.where((s) => s.student.id == id).firstOrNull;
        if (found == null) {
          throw const InvariantViolation(InvariantCode.actionNotAllowed);
        }
        final theirs = [for (final Group g in found.groups) g.id];
        groups.addAll(theirs.where((g) => !groups.contains(g)));
        published.add(
          PublishedStudent(
            id: id,
            firstName: found.student.firstName,
            audience: found.student.currentAudience,
            groupIds: theirs,
          ),
        );
      }
    }
    await _directory.publish(session.club, published);
    final invitation = Invitation.issue(
      code: _codes.next(),
      issuer: session.role,
      issuerId: session.user,
      clubId: session.club,
      role: role,
      now: _clock.now(),
      groupIds: groups,
      studentIds: [...studentIds],
    );
    await _invitations.create(invitation);
    await _issued.remember(session.user, session.club, invitation);
    return invitation;
  });
}
