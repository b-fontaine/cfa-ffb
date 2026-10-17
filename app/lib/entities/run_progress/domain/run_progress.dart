import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_progress.freezed.dart';

/// Plus grand score de jeu saisi à la main.
const maxRunScore = 999;

/// Où en est une séance guidée commencée (lot 10b, ADR 0020) : étape,
/// compteurs d'initiation, grille « acquis », score A / B, minuteur, saisie
/// ouverte depuis le guide et étiquettes de la note de jeu.
///
/// **Aucun identifiant d'élève** : la saisie n'est retenue que par son
/// identifiant ([recordId]) ; son groupe, sa date et ses absents sont relus de
/// la saisie à la reprise. Donnée transitoire, locale à l'appareil, hors
/// sauvegarde.
///
/// Les bornes qui dépendent de la séance du catalogue (dernière étape,
/// initiations qui existent, essais par initiation) ne sont pas de cette
/// entité : elles sont réappliquées à la reprise.
@freezed
abstract class RunProgress with _$RunProgress {
  factory RunProgress({
    required RunProgressKey key,
    required DateTime updatedAt,

    /// Étape courante (à partir de 0).
    @Default(0) int step,

    /// Réussites comptées par identifiant d'initiation.
    @Default(<String, int>{}) Map<String, int> counts,

    /// Critères acquis (indices) par identifiant d'initiation à grille.
    @Default(<String, Set<int>>{}) Map<String, Set<int>> checked,
    @Default(0) int scoreA,
    @Default(0) int scoreB,

    /// Secondes écoulées du minuteur de la phase courante.
    @Default(0) int timerSeconds,

    /// Saisie des résultats ouverte depuis le guide.
    SessionId? recordId,

    /// Étiquettes de la note de jeu (liste fermée, ADR 0023), choisies à
    /// l'étape « Bilan » : elles passent à la saisie à « Terminer ».
    @Default(<SessionTag>{}) Set<SessionTag> tags,
  }) = _RunProgress;

  RunProgress._() {
    if (step < 0 || timerSeconds < 0) {
      throw const InvariantViolation(InvariantCode.invalidRange);
    }
    if (counts.entries.any((e) => e.key.isEmpty || e.value < 0) ||
        this.checked.entries.any(
          (e) => e.key.isEmpty || e.value.any((index) => index < 0),
        )) {
      throw const InvariantViolation(InvariantCode.invalidRange);
    }
    if (scoreA < 0 ||
        scoreA > maxRunScore ||
        scoreB < 0 ||
        scoreB > maxRunScore) {
      throw const InvariantViolation(InvariantCode.scoreOutOfRange);
    }
  }
}
