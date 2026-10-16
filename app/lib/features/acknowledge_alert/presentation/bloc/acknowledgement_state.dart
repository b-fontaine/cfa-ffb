part of 'acknowledgement_bloc.dart';

enum AcknowledgementStatus { idle, working, done, refused }

enum AcknowledgementAction { acknowledge, restore }

/// Dernière demande d'acquittement : son [action], l'[exercise] visé et son
/// issue ([failure] quand elle est refusée).
@freezed
abstract class AcknowledgementState with _$AcknowledgementState {
  const factory AcknowledgementState({
    @Default(AcknowledgementStatus.idle) AcknowledgementStatus status,
    AcknowledgementAction? action,
    ExerciseRef? exercise,
    Failure? failure,
  }) = _AcknowledgementState;
}
