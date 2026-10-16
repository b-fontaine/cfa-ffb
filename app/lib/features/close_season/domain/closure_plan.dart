import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'closure_plan.freezed.dart';

/// Ce que l'assistant de clôture montre avant d'agir : la saison, le jour de
/// clôture proposé, les chiffres de l'archive à venir (aperçu) et une
/// proposition par élève.
@freezed
abstract class ClosurePlan with _$ClosurePlan {
  const factory ClosurePlan({
    required Season season,

    /// Jour de clôture proposé (le jour courant, ou la fin de saison si elle
    /// est passée).
    required DateTime closedOn,

    /// La clôture a lieu avant la fin prévue : la fin de saison sera ramenée
    /// au jour de clôture.
    required bool early,

    /// Aperçu de l'archive : un bloc par public ayant eu des séances.
    required List<AudienceArchive> audiences,
    required List<ClosureProposal> proposals,

    /// Séances planifiées de la saison postérieures à [closedOn].
    required int plannedToDrop,
  }) = _ClosurePlan;

  const ClosurePlan._();

  int get sessionCount => audiences.fold(0, (sum, a) => sum + a.sessionCount);

  int get presenceCount => audiences.fold(0, (sum, a) => sum + a.presenceCount);
}
