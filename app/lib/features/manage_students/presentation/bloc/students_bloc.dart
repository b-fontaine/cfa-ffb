import 'dart:async';

import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/domain/get_club_overview.dart';
import 'package:billard_cfa/features/manage_students/domain/watch_club_overview.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/live_reload.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'students_bloc.freezed.dart';
part 'students_event.dart';
part 'students_state.dart';

/// Les groupes de la saison et leurs élèves (liste, choix d'un groupe).
///
/// **Temps réel (FB5b)** : la liste suit les données dont elle dérive
/// (`WatchClubOverview`) et se recharge **en place**, sans état de
/// chargement, quand elles changent (un autre appareil inscrit un élève,
/// saisit un passage, acquitte une alerte). Un seul abonnement par bloc, fermé
/// avec lui, même si plusieurs écrans le partagent ; un échec s'affiche comme
/// à un chargement ordinaire, « Réessayer » rouvre l'écoute.
@injectable
class StudentsBloc extends Bloc<StudentsEvent, StudentsState> {
  StudentsBloc(this._overview, this._watch, this._clock)
    : super(const StudentsState()) {
    on<StudentsStarted>(_onStarted);
    on<StudentsRefreshed>(_onRefreshed);
    on<StudentsChanged>(_onChanged);
    _live = LiveReload(open: _watch.call, reload: _requestReload);
  }

  final GetClubOverview _overview;
  final WatchClubOverview _watch;
  final Clock _clock;
  late final LiveReload _live;

  Future<void> _onStarted(
    StudentsStarted event,
    Emitter<StudentsState> emit,
  ) async {
    // L'abonnement précède la lecture : un changement entre les deux est lu.
    _live.start();
    await _load(emit);
  }

  Future<void> _onRefreshed(
    StudentsRefreshed event,
    Emitter<StudentsState> emit,
  ) async {
    if (state.status == StudentsStatus.failure) {
      _live.restart();
    } else {
      _live.start();
    }
    await _load(emit);
  }

  Future<void> _onChanged(
    StudentsChanged event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _read(emit);
    } finally {
      event.done.complete();
    }
  }

  Future<void> _requestReload() {
    if (isClosed) return Future.value();
    final done = Completer<void>();
    add(StudentsEvent.changed(done: done));
    return done.future;
  }

  @override
  Future<void> close() async {
    await _live.stop();
    await super.close();
  }

  Future<void> _load(Emitter<StudentsState> emit) async {
    emit(state.copyWith(status: StudentsStatus.loading));
    await _read(emit);
  }

  Future<void> _read(Emitter<StudentsState> emit) async {
    switch (await _overview(today: _clock.today())) {
      case Ok(:final value):
        emit(StudentsState(status: StudentsStatus.ready, club: value));
      case Err(:final failure):
        emit(StudentsState(status: StudentsStatus.failure, failure: failure));
    }
  }
}
