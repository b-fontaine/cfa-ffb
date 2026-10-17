import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'member.freezed.dart';

/// Un compte dans un club (document `members` de l'ADR 0024) : son rôle, son
/// nom affiché à l'équipe et son périmètre (groupes, fiches liées).
///
/// Un compte a un rôle par club ; l'administrateur n'a pas de `Member` (il agit
/// par son document `admins`).
@freezed
abstract class Member with _$Member {
  factory Member({
    required UserId uid,
    required Role role,
    required String displayName,
    @Default(<GroupId>[]) List<GroupId> groupIds,
    @Default(<StudentId>[]) List<StudentId> studentIds,
    DateTime? joinedAt,
  }) = _Member;

  Member._() {
    if (displayName.trim().isEmpty) {
      throw const InvariantViolation(InvariantCode.nameRequired);
    }
    if (displayName.trim().length > maxDisplayNameLength) {
      throw const InvariantViolation(InvariantCode.nameTooLong);
    }
  }

  /// Vrai pour un rôle que le directeur peut retirer (jamais un directeur :
  /// les règles réservent ce droit à l'administrateur).
  bool get removableByDirector => role != Role.director && role != Role.admin;
}
