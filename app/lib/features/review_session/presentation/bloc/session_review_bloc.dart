import 'package:billard_cfa/features/review_session/domain/get_session_review.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'session_review_bloc.freezed.dart';
part 'session_review_event.dart';
part 'session_review_state.dart';

/// Le bilan d'une séance donnée.
@injectable
class SessionReviewBloc extends Bloc<SessionReviewEvent, SessionReviewState> {
  SessionReviewBloc(this._get) : super(const SessionReviewState()) {
    on<SessionReviewStarted>(_onStarted);
  }

  final GetSessionReview _get;

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
