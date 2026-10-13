import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/session_sheet_timing.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_timing.freezed.dart';

/// Minutes calculées d'une séance pour un public `[Prop]`.
///
/// Les cartes ne contiennent que les éléments affichés pour ce public.
@freezed
abstract class SheetTiming with _$SheetTiming {
  const factory SheetTiming({
    required Map<SessionPhase, int> phaseMinutes,
    required int recall,
    required Map<String, int> theory,
    required Map<String, int> initiation,
    required Map<String, int> exercises,
    required int game,
    required int review,
  }) = _SheetTiming;

  const SheetTiming._();

  /// Durée totale : 90 min (enfants) ou 120 min (adultes) par construction.
  int get total => phaseMinutes.values.fold(0, (sum, m) => sum + m);
}

/// Minutage de [sheet] pour [audience], budgets lus dans [shapes]
/// (`RulesConfig.shapes`) : plus fort reste, somme exacte (FORMAT § 4).
SheetTiming sheetTiming(
  SessionSheet sheet, {
  required Audience audience,
  required Map<Audience, SessionShape> shapes,
}) {
  final theory = [
    for (final s in sheet.theorySections)
      if (s.weight.isShownFor(audience)) s,
  ];
  final initiation = [
    for (final i in sheet.initiation)
      if (i.weight.isShownFor(audience)) i,
  ];
  final exercises = [
    for (final e in sheet.exercises)
      if (e.weight.isShownFor(audience)) e,
  ];
  final minutes = sessionSheetTiming(
    audience: audience,
    shapes: shapes,
    weights: {
      SessionPhase.welcome: [1],
      SessionPhase.notionAndInitiation: [
        for (final s in theory) s.weight.of(audience),
        for (final i in initiation) i.weight.of(audience),
      ],
      SessionPhase.training: [for (final e in exercises) e.weight.of(audience)],
      SessionPhase.game: [sheet.game.weight.of(audience)],
      SessionPhase.review: [1],
    },
  );
  final notion = minutes[SessionPhase.notionAndInitiation]!;
  final training = minutes[SessionPhase.training]!;
  return SheetTiming(
    phaseMinutes: {
      for (final entry in minutes.entries)
        entry.key: entry.value.fold(0, (sum, m) => sum + m),
    },
    recall: minutes[SessionPhase.welcome]!.single,
    theory: {for (final (i, s) in theory.indexed) s.id: notion[i]},
    initiation: {
      for (final (i, item) in initiation.indexed)
        item.id: notion[theory.length + i],
    },
    exercises: {for (final (i, e) in exercises.indexed) e.id: training[i]},
    game: minutes[SessionPhase.game]!.single,
    review: minutes[SessionPhase.review]!.single,
  );
}
