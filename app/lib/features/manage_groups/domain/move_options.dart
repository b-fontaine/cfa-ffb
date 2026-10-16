import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'move_options.freezed.dart';

/// Ce que la feuille « Changer de groupe » propose pour un élève.
@freezed
abstract class MoveOptions with _$MoveOptions {
  const factory MoveOptions({
    required StudentId studentId,
    required String firstName,

    /// Les groupes où le déplacer : même saison, même public, hors le groupe
    /// actuel.
    required List<GroupChoice> destinations,

    /// Le groupe actuel de l'élève ; `null` s'il n'en a pas.
    GroupChoice? current,
  }) = _MoveOptions;
}
