import 'package:billard_cfa/features/plan_session/domain/get_upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/upcoming_sessions.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'upcoming_sessions_cubit.freezed.dart';

enum UpcomingStatus { loading, ready, failure }

@freezed
abstract class UpcomingSessionsState with _$UpcomingSessionsState {
  const factory UpcomingSessionsState({
    @Default(UpcomingStatus.loading) UpcomingStatus status,
    @Default(UpcomingSessions()) UpcomingSessions upcoming,
    Failure? failure,
  }) = _UpcomingSessionsState;
}

/// Séance à venir et séances à noter de l'accueil : sa propre section, son
/// propre échec.
@injectable
class UpcomingSessionsCubit extends Cubit<UpcomingSessionsState> {
  UpcomingSessionsCubit(this._get) : super(const UpcomingSessionsState());

  final GetUpcomingSessions _get;

  /// (Re)charge la section ; sert aussi de « Réessayer ».
  Future<void> load() async {
    if (state.status != UpcomingStatus.loading) {
      emit(const UpcomingSessionsState());
    }
    final result = await _get();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => UpcomingSessionsState(
        status: UpcomingStatus.ready,
        upcoming: value,
      ),
      Err(:final failure) => UpcomingSessionsState(
        status: UpcomingStatus.failure,
        failure: failure,
      ),
    });
  }
}
