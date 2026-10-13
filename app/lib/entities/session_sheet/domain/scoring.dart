import 'package:freezed_annotation/freezed_annotation.dart';

part 'scoring.freezed.dart';

/// Notation locale d'un élément d'initiation (jamais enregistrée dans le
/// suivi) : les exercices du catalogue sont notés par `RecordAttempt`.
@freezed
sealed class Scoring with _$Scoring {
  /// « réussis sur [of] essais », compté pendant la séance.
  const factory Scoring.counter({required int of}) = CounterScoring;

  /// Cases « acquis / à retravailler » pour des [criteria] observables.
  const factory Scoring.checklist({required List<String> criteria}) =
      ChecklistScoring;
}
