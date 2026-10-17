import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'club.freezed.dart';

/// Un club (ADR 0024, décision 14) : son nom et sa saison courante. Les
/// règles du serveur bornent le nom à [maxClubNameLength] caractères.
@freezed
abstract class Club with _$Club {
  factory Club({
    required ClubId id,
    required String name,
    SeasonId? currentSeasonId,
  }) = _Club;

  Club._() {
    if (name.trim().isEmpty) {
      throw const InvariantViolation(InvariantCode.nameRequired);
    }
    if (name.trim().length > maxClubNameLength) {
      throw const InvariantViolation(InvariantCode.nameTooLong);
    }
  }

  /// Le même club sous un autre nom.
  Club rename(String newName) =>
      Club(id: id, name: newName.trim(), currentSeasonId: currentSeasonId);
}
