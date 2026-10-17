import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';

/// Le compte [viewerId], de rôle [viewerRole], peut-il retirer l'accès de
/// [member] au club ? Règle unique, lue par le cas d'usage (qui refuse) et par
/// l'état de « Mon club » (qui n'affiche l'action que si elle est permise) :
///
/// - il faut gérer le club (directeur, administrateur) ;
/// - personne ne se retire soi-même ;
/// - le directeur retire enseignants, élèves et parents, jamais un directeur ;
///   l'administrateur retire aussi un directeur (règles Firestore, ADR 0024
///   décision 14).
bool canRemoveMember({
  required Role viewerRole,
  required UserId viewerId,
  required Member member,
}) =>
    viewerRole.can(Capability.manageClub) &&
    member.uid != viewerId &&
    (viewerRole != Role.director || member.removableByDirector);
