import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'club_membership.freezed.dart';

/// L'appartenance d'un compte à un club, avec son rôle (ADR 0024,
/// décision 14).
@freezed
abstract class ClubMembership with _$ClubMembership {
  const factory ClubMembership({
    required ClubId clubId,
    required String clubName,
    required Role role,
  }) = _ClubMembership;
}
