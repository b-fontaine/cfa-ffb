import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_suggestion.freezed.dart';

/// Pourquoi cette séance du catalogue est proposée (ADR 0009).
enum SheetSuggestionKind {
  /// Séance encore à faire qui contient l'exercice de tête.
  coversHead,

  /// Séance encore à faire qui ne contient pas l'exercice de tête : celle-ci
  /// relève d'une partie déjà donnée, la proposée est la partie suivante.
  nextPending,

  /// Toutes les parties sont faites : celle de l'exercice de tête, redonnée.
  repeat,
}

/// Séance du catalogue proposée pour la notion principale d'une séance
/// suggérée (valeur dérivée, jamais stockée).
@freezed
abstract class SheetSuggestion with _$SheetSuggestion {
  const factory SheetSuggestion({
    required SheetOption option,
    required SheetSuggestionKind kind,

    /// Numéros des exercices du bloc que la séance contient, dans l'ordre de
    /// la séance.
    required List<int> exerciseNumbers,

    /// La séance contient l'exercice de tête de la suggestion.
    required bool headCovered,

    /// Exercice de tête de la suggestion.
    required ExerciseRef head,

    /// Jour (minuit local) de la saisie faite la plus récente de la séance ;
    /// renseigné pour [SheetSuggestionKind.repeat], nul sinon.
    DateTime? lastGivenOn,
  }) = _SheetSuggestion;
}
