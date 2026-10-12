import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_ref.freezed.dart';

/// Référence d'un exercice du catalogue : bloc + numéro (à partir de 1).
@freezed
abstract class ExerciseRef with _$ExerciseRef {
  factory ExerciseRef({required String blockId, required int number}) =
      _ExerciseRef;

  ExerciseRef._() {
    if (blockId.trim().isEmpty || number < 1) {
      throw const InvariantViolation(InvariantCode.invalidExerciseRef);
    }
  }

  /// Référence issue de segments d'adresse, ou `null` si bloc ou numéro sont
  /// invalides (jamais d'exception : une adresse saisie peut être fausse).
  static ExerciseRef? tryParse(String blockId, String number) {
    final parsed = int.tryParse(number);
    if (parsed == null || parsed < 1 || blockId.trim().isEmpty) return null;
    return ExerciseRef(blockId: blockId, number: parsed);
  }
}
