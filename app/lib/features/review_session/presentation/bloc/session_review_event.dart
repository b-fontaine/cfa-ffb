part of 'session_review_bloc.dart';

@freezed
sealed class SessionReviewEvent with _$SessionReviewEvent {
  /// Charge le bilan de la saisie [sessionId] (ou le recharge).
  const factory SessionReviewEvent.started(SessionId sessionId) =
      SessionReviewStarted;

  /// L'animateur fixe les étiquettes de la note de jeu (ADR 0023) : elles
  /// remplacent les précédentes.
  const factory SessionReviewEvent.tagsChanged(Set<SessionTag> tags) =
      SessionReviewTagsChanged;
}
