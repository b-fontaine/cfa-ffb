import 'package:billard_cfa/features/plan_session/domain/get_upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/watch_upcoming_sessions.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/live_reload.dart';
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
///
/// **Temps réel (FB5b)** : la section suit les séances planifiées, les séances
/// données et les groupes (`WatchUpcomingSessions`) et se recharge **en
/// place** quand un autre appareil les change (une séance planifiée, ou saisie
/// ailleurs). Un seul abonnement, ouvert au premier [load], fermé avec le
/// cubit ; un échec rouvre l'écoute au prochain [load] (« Réessayer »).
@injectable
class UpcomingSessionsCubit extends Cubit<UpcomingSessionsState> {
  UpcomingSessionsCubit(this._get, this._watch)
    : super(const UpcomingSessionsState()) {
    _live = LiveReload(open: _watch.call, reload: _refresh);
  }

  final GetUpcomingSessions _get;
  final WatchUpcomingSessions _watch;
  late final LiveReload _live;

  /// (Re)charge la section ; sert aussi de « Réessayer ».
  Future<void> load() async {
    if (state.status == UpcomingStatus.failure) {
      _live.restart();
    } else {
      _live.start();
    }
    if (state.status != UpcomingStatus.loading) {
      emit(const UpcomingSessionsState());
    }
    await _refresh();
  }

  /// Relit la section sans repasser par le chargement.
  Future<void> _refresh() async {
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

  @override
  Future<void> close() async {
    await _live.stop();
    await super.close();
  }
}
