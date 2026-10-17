import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';

/// Ramène une progression enregistrée à la séance du catalogue **telle qu'elle
/// est aujourd'hui** (ADR 0020 § 5.3) : la fiche a pu être raccourcie ou
/// modifiée depuis l'enregistrement.
///
/// - l'étape est ramenée dans la plage du déroulé ;
/// - un compteur ou une grille d'une initiation qui n'existe plus, ou qui n'a
///   plus ce type de notation, est retiré ;
/// - un compteur est ramené au nombre d'essais, les critères inconnus de la
///   grille sont retirés.
///
/// Le score, le minuteur et la saisie ne dépendent pas de la fiche : intacts.
/// Pure et idempotente.
RunProgress reconcileRunProgress(RunProgress progress, RunPlan plan) {
  final scoring = {
    for (final initiation in plan.sheet.initiation)
      initiation.id: initiation.scoring,
  };
  return progress.copyWith(
    step: plan.clamp(progress.step),
    counts: {
      for (final entry in progress.counts.entries)
        if (scoring[entry.key] case CounterScoring(:final of))
          entry.key: entry.value.clamp(0, of),
    },
    checked: {
      for (final entry in progress.checked.entries)
        if (scoring[entry.key] case ChecklistScoring(:final criteria))
          entry.key: {
            for (final index in entry.value)
              if (index < criteria.length) index,
          },
    },
  );
}

/// Vrai si la progression de [key] n'a plus de séance planifiée à laquelle se
/// rattacher : elle nommait une séance planifiée que [plan] ne retrouve plus
/// (supprimée depuis l'enregistrement). La fiche, elle, existe : le guide
/// repart à neuf et l'état gardé est oublié (ADR 0020 § 5.3).
bool isOrphanedProgress(RunProgressKey key, RunPlan plan) =>
    key.sessionId != null && plan.planned == null;
