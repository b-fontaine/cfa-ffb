import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_progress.freezed.dart';

/// Résultats d'un élève par exercice (uniquement les exercices pratiqués) et
/// blocs acquis au positionnement (ADR 0008).
@freezed
abstract class StudentProgress with _$StudentProgress {
  const factory StudentProgress({
    required StudentId studentId,
    required Map<ExerciseRef, ExerciseResult> results,

    /// Marqueur retenu par bloc marqué (le plus récent), y compris celui dont
    /// tous les exercices ont été repris par des passages (marqueur dormant).
    @Default(<String, BlockAcquisition>{})
    Map<String, BlockAcquisition> acquiredBlocks,

    /// Exercices encore acquis : aucun passage daté du jour du positionnement
    /// ou après n'a repris la main sur eux.
    @Default(<ExerciseRef>{}) Set<ExerciseRef> acquiredExercises,

    /// Exercices d'un bloc marqué repris par des passages.
    @Default(<ExerciseRef>{}) Set<ExerciseRef> resumedExercises,

    /// Alertes actuellement vues par l'animateur (ADR 0013) : un acquittement
    /// par exercice, seulement tant qu'il masque une alerte (le dernier
    /// passage de l'exercice est celui du « Vu » et l'alerte serait active).
    @Default(<ExerciseRef, AlertAcknowledgement>{})
    Map<ExerciseRef, AlertAcknowledgement> acknowledgedAlerts,
  }) = _StudentProgress;

  const StudentProgress._();

  /// Regroupe les [attempts] de l'élève par exercice et dérive chaque résultat.
  ///
  /// [rates] vient du catalogue ; un passage sur un exercice inconnu est une
  /// violation (`unknownExercise`). [acquisitions] : les marqueurs de l'élève
  /// sont filtrés ; plusieurs marqueurs pour un même bloc, le plus récent
  /// gagne ; un bloc inconnu de [rates] est ignoré. Un exercice d'un bloc
  /// marqué est acquis tant qu'aucun passage sur cet exercice n'est daté du
  /// jour du positionnement ou après (`dateOnly`, `>=`).
  ///
  /// [acknowledgements] (ADR 0013) : les « Vu » de l'élève sont filtrés ;
  /// pour un même exercice, le plus récent gagne. Un « Vu » masque l'alerte
  /// tant que le dernier passage de l'exercice est celui auquel il est lié ;
  /// il ne modifie ni les résultats ni les échecs consécutifs.
  factory StudentProgress.derive({
    required StudentId studentId,
    required List<ExerciseAttempt> attempts,
    required List<BlockAcquisition> acquisitions,
    required Map<ExerciseRef, SuccessRate> rates,
    required RulesConfig config,
    List<AlertAcknowledgement> acknowledgements = const [],
  }) {
    final byExercise = <ExerciseRef, List<ExerciseAttempt>>{};
    for (final attempt in attempts.where((a) => a.studentId == studentId)) {
      (byExercise[attempt.exercise] ??= []).add(attempt);
    }
    final results = <ExerciseRef, ExerciseResult>{};
    for (final entry in byExercise.entries) {
      final rate = rates[entry.key];
      if (rate == null) {
        throw const InvariantViolation(InvariantCode.unknownExercise);
      }
      results[entry.key] = ExerciseResult.derive(
        studentId: studentId,
        exercise: entry.key,
        rate: rate,
        attempts: entry.value,
        config: config,
      );
    }
    final latest = <String, BlockAcquisition>{};
    for (final acquisition in acquisitions.where(
      (a) => a.studentId == studentId,
    )) {
      final known = latest[acquisition.blockId];
      if (known == null || !acquisition.date.isBefore(known.date)) {
        latest[acquisition.blockId] = acquisition;
      }
    }
    final marked = <String, BlockAcquisition>{};
    final acquired = <ExerciseRef>{};
    final resumed = <ExerciseRef>{};
    for (final acquisition in latest.values) {
      final exercises = [
        for (final ref in rates.keys)
          if (ref.blockId == acquisition.blockId) ref,
      ];
      if (exercises.isEmpty) continue;
      marked[acquisition.blockId] = acquisition;
      for (final exercise in exercises) {
        final taken = (byExercise[exercise] ?? const []).any(
          (a) => a.date.dateOnly.compareTo(acquisition.date.dateOnly) >= 0,
        );
        (taken ? resumed : acquired).add(exercise);
      }
    }
    final latestSeen = <ExerciseRef, AlertAcknowledgement>{};
    for (final acknowledgement in acknowledgements.where(
      (a) => a.studentId == studentId,
    )) {
      final known = latestSeen[acknowledgement.exercise];
      if (known == null || !acknowledgement.date.isBefore(known.date)) {
        latestSeen[acknowledgement.exercise] = acknowledgement;
      }
    }
    final seen = <ExerciseRef, AlertAcknowledgement>{
      for (final entry in latestSeen.entries)
        if (results[entry.key] case final result?
            when result.hasActiveAlert &&
                result.lastAttempt?.id == entry.value.lastAttemptId)
          entry.key: entry.value,
    };
    return StudentProgress(
      studentId: studentId,
      results: Map.unmodifiable(results),
      acquiredBlocks: Map.unmodifiable(marked),
      acquiredExercises: Set.unmodifiable(acquired),
      resumedExercises: Set.unmodifiable(resumed),
      acknowledgedAlerts: Map.unmodifiable(seen),
    );
  }

  /// Exercices validés (entrée de `ExerciseCatalogue.nextExercise`) : validés
  /// par passages ou encore acquis au positionnement.
  Set<ExerciseRef> get validated => {
    for (final result in results.values.where((r) => r.isValidated))
      result.exercise,
    ...acquiredExercises,
  };

  /// Parcours « à commencer » : aucun passage et aucun exercice validé ou
  /// acquis. Un élève qui a pratiqué sans rien valider n'est pas à commencer.
  /// Définition unique, partagée par la fiche, la liste et la vue élève.
  bool get toStart => validated.isEmpty && results.isEmpty;

  /// Exercices dont l'alerte d'échecs consécutifs est active (R4) ; celle d'un
  /// exercice encore acquis est masquée, celle d'un exercice vu par l'animateur
  /// (« Vu », ADR 0013) aussi.
  List<ExerciseResult> get activeAlerts => [
    for (final result in results.values.where(
      (r) =>
          r.hasActiveAlert &&
          !acquiredExercises.contains(r.exercise) &&
          !acknowledgedAlerts.containsKey(r.exercise),
    ))
      result,
  ];

  /// Exercices dont l'alerte a été vue par l'animateur : le niveau d'alerte et
  /// les échecs restent ceux du résultat (le « Vu » ne change que l'affichage).
  List<ExerciseResult> get acknowledgedAlertResults => [
    for (final result in results.values.where(
      (r) =>
          acknowledgedAlerts.containsKey(r.exercise) &&
          !acquiredExercises.contains(r.exercise),
    ))
      result,
  ];

  /// Tous les exercices du bloc sont acquis (marqueur sans exercice repris).
  bool isAcquired(String blockId) =>
      acquiredBlocks.containsKey(blockId) && resumedCount(blockId) == 0;

  /// Jour du positionnement du bloc ; `null` si le bloc n'est pas marqué.
  DateTime? acquiredOn(String blockId) => acquiredBlocks[blockId]?.date;

  /// Exercices du bloc repris par des passages depuis le positionnement.
  int resumedCount(String blockId) =>
      resumedExercises.where((ref) => ref.blockId == blockId).length;
}
