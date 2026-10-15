import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_recall_slot.freezed.dart';

/// Créneau d'exercice de rappel d'une séance (ADR 0011) : un emplacement de
/// la phase d'entraînement, après les exercices, dont l'exercice est choisi à
/// l'exécution parmi ceux des séances précédentes d'après le suivi des élèves.
///
/// Le créneau ne nomme jamais d'exercice ; il porte son poids `[Prop]` dans le
/// minutage et les passages prévus (1 ou 2, comme un exercice).
@freezed
abstract class SheetRecallSlot with _$SheetRecallSlot {
  const factory SheetRecallSlot({
    required AudienceWeight weight,
    required int passes,
  }) = _SheetRecallSlot;
}
