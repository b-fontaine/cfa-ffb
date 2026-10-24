import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/closure_plan.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/features/close_season/domain/prepare_season_closure.dart';
import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/closure_limits.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'season_closure_bloc.freezed.dart';
part 'season_closure_event.dart';
part 'season_closure_state.dart';

/// L'assistant de clôture d'une saison (ADR 0019) : la proposition par élève
/// (modifiable ligne par ligne), les deux options, puis la clôture. La
/// confirmation (case « J'ai compris ») est demandée par l'écran.
///
/// Dans un club synchronisé, la clôture se fait par lots reprenables (ADR
/// 0024, décision 19 ; FB8) : l'avancement est montré, l'arrêt se prend entre
/// deux lots, et une clôture commencée se **reprend** à l'ouverture de
/// l'assistant (sans rien redemander : les termes sont dans le marqueur).
@injectable
class SeasonClosureBloc extends Bloc<SeasonClosureEvent, SeasonClosureState> {
  SeasonClosureBloc(this._prepare, this._closing, this._clock)
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
    on<SeasonClosureResumed>(_onResumed);
    on<SeasonClosureStopRequested>((event, emit) => _stop = true);
  }

  final PrepareSeasonClosure _prepare;
  final SeasonClosing _closing;
  final Clock _clock;
  bool _stop = false;

  Future<void> _onStarted(
    SeasonClosureStarted event,
    Emitter<SeasonClosureState> emit,
  ) async {
    emit(SeasonClosureState(synchronized: _closing.synchronized));
    // Une clôture de cette saison, commencée et non terminée : à reprendre,
    // avant toute autre chose (la saison est peut-être déjà close).
    if (_closing.synchronized) {
      switch (await _closing.pending()) {
        case Ok(:final value) when value?.seasonId == event.seasonId:
          emit(
            state.copyWith(
              status: SeasonClosureStatus.resumable,
              pending: value,
            ),
          );
          return;
        case Ok():
          break;
        case Err(:final failure):
          // Un marqueur illisible n'est pas « aucune clôture commencée » :
          // proposer une nouvelle clôture avec d'autres choix serait faux.
          emit(
            state.copyWith(
              status: SeasonClosureStatus.failure,
              failure: failure,
            ),
          );
          return;
      }
    }
    switch (await _prepare(seasonId: event.seasonId, today: _clock.today())) {
      case Ok(:final value):
        // Les invitations à supprimer : un aperçu, jamais une condition (un
        // échec de lecture ne montre aucun chiffre).
        final invitations = _closing.synchronized
            ? switch (await _closing.invitationsToPurge()) {
                Ok(:final value) => value,
                Err() => null,
              }
            : null;
        emit(
          state.copyWith(
            status: SeasonClosureStatus.ready,
            plan: value,
            choices: {for (final p in value.proposals) p.studentId: p.choice},
            invitationsToPurge: invitations,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: SeasonClosureStatus.failure, failure: failure),
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
    if (state.tooManyToErase) {
      emit(
        state.copyWith(
          failure: const InvariantViolation(InvariantCode.tooManyToErase),
        ),
      );
      return;
    }
    _stop = false;
    emit(
      state.copyWith(
        status: SeasonClosureStatus.closing,
        failure: null,
        done: 0,
        total: 0,
      ),
    );
    final result = await _closing.close(
      seasonId: plan.season.id,
      closedOn: plan.closedOn,
      erase: {
        for (final entry in state.choices.entries)
          if (entry.value == ClosureChoice.erase) entry.key,
      },
      prepareNext: state.prepareNext,
      dropPlanned: state.dropPlanned,
      shouldStop: () => _stop,
      onProgress: _progress(emit),
    );
    _finish(result, emit, back: SeasonClosureStatus.ready);
  }

  Future<void> _onResumed(
    SeasonClosureResumed event,
    Emitter<SeasonClosureState> emit,
  ) async {
    final terms = state.pending;
    if (terms == null) return;
    _stop = false;
    emit(
      state.copyWith(
        status: SeasonClosureStatus.closing,
        failure: null,
        done: 0,
        total: 0,
      ),
    );
    final result = await _closing.resume(
      terms,
      shouldStop: () => _stop,
      onProgress: _progress(emit),
    );
    _finish(result, emit, back: SeasonClosureStatus.resumable);
  }

  void Function(int, int) _progress(Emitter<SeasonClosureState> emit) =>
      (done, total) {
        if (!emit.isDone) emit(state.copyWith(done: done, total: total));
      };

  void _finish(
    Result<ClosureOutcome> result,
    Emitter<SeasonClosureState> emit, {
    required SeasonClosureStatus back,
  }) {
    if (emit.isDone) return;
    switch (result) {
      case Ok(:final value):
        final status = switch (value.status) {
          OperationRunStatus.completed => SeasonClosureStatus.closed,
          OperationRunStatus.cancelled => SeasonClosureStatus.stopped,
          OperationRunStatus.interrupted => SeasonClosureStatus.interrupted,
          OperationRunStatus.paused => SeasonClosureStatus.paused,
          OperationRunStatus.failed => SeasonClosureStatus.failure,
        };
        emit(
          state.copyWith(
            status: status,
            result: value.result,
            // Une clôture arrêtée en route se retrouve par son marqueur : on
            // en garde les termes pour la reprendre sans rien redemander.
            pending: status == SeasonClosureStatus.closed ? null : _terms(),
            done: value.doneLots == 0 ? state.done : value.doneLots,
            total: value.totalLots == 0 ? state.total : value.totalLots,
            failure: value.failure,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: back, failure: failure));
    }
  }

  ClosureTerms? _terms() {
    final plan = state.plan;
    if (plan == null) return state.pending;
    return ClosureTerms(
      seasonId: plan.season.id,
      closedOn: plan.closedOn,
      prepareNext: state.prepareNext,
      dropPlanned: state.dropPlanned,
    );
  }
}
