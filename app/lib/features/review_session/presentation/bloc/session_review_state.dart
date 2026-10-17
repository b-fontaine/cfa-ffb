part of 'session_review_bloc.dart';

enum SessionReviewStatus { loading, ready, failure }

@freezed
abstract class SessionReviewState with _$SessionReviewState {
  const factory SessionReviewState({
    @Default(SessionReviewStatus.loading) SessionReviewStatus status,
    SessionReview? review,

    /// `NotFound` pour une saisie inconnue (page absente).
    Failure? failure,

    /// Échec de la dernière écriture des étiquettes : le bilan reste affiché,
    /// avec les étiquettes d'avant.
    Failure? tagsFailure,
  }) = _SessionReviewState;
}
