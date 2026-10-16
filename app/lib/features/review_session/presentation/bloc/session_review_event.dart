part of 'session_review_bloc.dart';

@freezed
sealed class SessionReviewEvent with _$SessionReviewEvent {
  /// Charge le bilan de la saisie [sessionId] (ou le recharge).
  const factory SessionReviewEvent.started(SessionId sessionId) =
      SessionReviewStarted;
}
