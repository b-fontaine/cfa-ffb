import 'package:billard_cfa/features/review_session/domain/get_session_review.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/features/review_session/domain/set_session_tags.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'session_review_bloc.freezed.dart';
part 'session_review_event.dart';
part 'session_review_state.dart';

/// Le bilan d'une séance donnée.
@injectable
class SessionReviewBloc extends Bloc<SessionReviewEvent, SessionReviewState> {
  SessionReviewBloc(this._get, this._setTags)
    : super(const SessionReviewState()) {
    on<SessionReviewStarted>(_onStarted);
    on<SessionReviewTagsChanged>(_onTagsChanged);
  }

  final GetSessionReview _get;
  final SetSessionTags _setTags;

  Future<void> _onTagsChanged(
    SessionReviewTagsChanged event,
    Emitter<SessionReviewState> emit,
  ) async {
    final review = state.review;
    if (state.status != SessionReviewStatus.ready || review == null) return;
    final previous = review.record.tags;
    // L'écran montre le choix tout de suite : un second choix, fait avant la
    // fin de l'écriture, part de ce résultat et ne perd pas le premier.
    emit(
      SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review.copyWith(
          record: review.record.copyWith(tags: event.tags),
        ),
      ),
    );
    if (await _setTags(review.record.id, event.tags) case Err(:final failure)) {
      final current = state.review;
      // Retour aux étiquettes d'avant, sauf si un choix plus récent a pris la
      // place de celui-ci.
      if (current == null || !setEquals(current.record.tags, event.tags)) {
        return;
      }
      emit(
        SessionReviewState(
          status: SessionReviewStatus.ready,
          review: current.copyWith(
            record: current.record.copyWith(tags: previous),
          ),
          tagsFailure: failure,
        ),
      );
    }
  }

  Future<void> _onStarted(
    SessionReviewStarted event,
    Emitter<SessionReviewState> emit,
  ) async {
    if (state.status != SessionReviewStatus.loading) {
      emit(const SessionReviewState());
    }
    switch (await _get(event.sessionId)) {
      case Ok(:final value):
        emit(
          SessionReviewState(status: SessionReviewStatus.ready, review: value),
        );
      case Err(:final failure):
        emit(
          SessionReviewState(
            status: SessionReviewStatus.failure,
            failure: failure,
          ),
        );
    }
  }
}
