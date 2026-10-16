import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/closure_plan.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/features/close_season/domain/prepare_season_closure.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'season_closure_bloc.freezed.dart';
part 'season_closure_event.dart';
part 'season_closure_state.dart';

/// L'assistant de clôture d'une saison (ADR 0019) : la proposition par élève
/// (modifiable ligne par ligne), les deux options, puis la clôture. La
/// confirmation (case « J'ai compris ») est demandée par l'écran.
@injectable
class SeasonClosureBloc extends Bloc<SeasonClosureEvent, SeasonClosureState> {
  SeasonClosureBloc(this._prepare, this._close, this._clock)
    : super(const SeasonClosureState()) {
    on<SeasonClosureStarted>(_onStarted);
    on<SeasonClosureChoiceSet>(_onChoiceSet);
    on<SeasonClosureAllSet>(_onAllSet);
    on<SeasonClosurePrepareNextSet>(
      (event, emit) => emit(state.copyWith(prepareNext: event.value)),
    );
    on<SeasonClosureDropPlannedSet>(
      (event, emit) => emit(state.copyWith(dropPlanned: event.value)),
    );
    on<SeasonClosureConfirmed>(_onConfirmed);
  }

  final PrepareSeasonClosure _prepare;
  final CloseSeason _close;
  final Clock _clock;

  Future<void> _onStarted(
    SeasonClosureStarted event,
    Emitter<SeasonClosureState> emit,
  ) async {
    emit(const SeasonClosureState());
    switch (await _prepare(seasonId: event.seasonId, today: _clock.today())) {
      case Ok(:final value):
        emit(
          SeasonClosureState(
            status: SeasonClosureStatus.ready,
            plan: value,
            choices: {for (final p in value.proposals) p.studentId: p.choice},
          ),
        );
      case Err(:final failure):
        emit(
          SeasonClosureState(
            status: SeasonClosureStatus.failure,
            failure: failure,
          ),
        );
    }
  }

  void _onChoiceSet(
    SeasonClosureChoiceSet event,
    Emitter<SeasonClosureState> emit,
  ) => emit(
    state.copyWith(choices: {...state.choices, event.studentId: event.choice}),
  );

  void _onAllSet(SeasonClosureAllSet event, Emitter<SeasonClosureState> emit) =>
      emit(
        state.copyWith(
          choices: {for (final id in state.choices.keys) id: event.choice},
        ),
      );

  Future<void> _onConfirmed(
    SeasonClosureConfirmed event,
    Emitter<SeasonClosureState> emit,
  ) async {
    final plan = state.plan;
    if (plan == null || state.status != SeasonClosureStatus.ready) return;
    emit(state.copyWith(status: SeasonClosureStatus.closing, failure: null));
    final result = await _close(
      seasonId: plan.season.id,
      closedOn: plan.closedOn,
      erase: {
        for (final entry in state.choices.entries)
          if (entry.value == ClosureChoice.erase) entry.key,
      },
      prepareNext: state.prepareNext,
      dropPlanned: state.dropPlanned,
    );
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: SeasonClosureStatus.closed, result: value));
      case Err(:final failure):
        emit(
          state.copyWith(status: SeasonClosureStatus.ready, failure: failure),
        );
    }
  }
}
