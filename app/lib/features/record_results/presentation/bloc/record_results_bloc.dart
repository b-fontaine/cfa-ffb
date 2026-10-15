import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/correct_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/delete_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/get_session_overview.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/session_overview.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'record_results_bloc.freezed.dart';
part 'record_results_event.dart';
part 'record_results_state.dart';

/// Saisie des passages d'une séance ouverte : exercice choisi, passages par
/// élève, retour immédiat (objectif, validation, alerte), correction et
/// suppression des passages déjà saisis.
@injectable
class RecordResultsBloc extends Bloc<RecordResultsEvent, RecordResultsState> {
  RecordResultsBloc(this._overview, this._record, this._correct, this._delete)
    : super(const RecordResultsState()) {
    on<RecordResultsStarted>(_onStarted);
    on<RecordResultsExerciseSelected>(_onExerciseSelected);
    on<RecordResultsPassSubmitted>(_onPassSubmitted);
    on<RecordResultsAttemptCorrected>(_onAttemptCorrected);
    on<RecordResultsAttemptDeleted>(_onAttemptDeleted);
  }

  final GetSessionOverview _overview;
  final RecordAttempt _record;
  final CorrectAttempt _correct;
  final DeleteAttempt _delete;

  Future<void> _onStarted(
    RecordResultsStarted event,
    Emitter<RecordResultsState> emit,
  ) async {
    emit(const RecordResultsState());
    switch (await _overview(event.sessionId)) {
      case Ok(:final value):
        final blockId = value.session.mainBlockId;
        final block = blockId == null
            ? null
            : value.catalogue.blockById(blockId);
        final exercises = block?.exercises ?? value.catalogue.exercises;
        final wanted = event.initialExercise;
        final wantedBlock = event.initialBlock == null
            ? block
            : value.catalogue.blockById(event.initialBlock!);
        final preselected = wantedBlock == null || wanted == null
            ? null
            : wantedBlock.exercises
                  .where((spec) => spec.ref.number == wanted)
                  .firstOrNull;
        emit(
          RecordResultsState(
            status: RecordStatus.ready,
            overview: value,
            exercise: (preselected ?? exercises.first).ref,
          ),
        );
      case Err(:final failure):
        emit(
          RecordResultsState(status: RecordStatus.failure, failure: failure),
        );
    }
  }

  void _onExerciseSelected(
    RecordResultsExerciseSelected event,
    Emitter<RecordResultsState> emit,
  ) {
    emit(
      state.copyWith(
        exercise: event.exercise,
        feedback: const {},
        refused: const {},
      ),
    );
  }

  Future<void> _onPassSubmitted(
    RecordResultsPassSubmitted event,
    Emitter<RecordResultsState> emit,
  ) async {
    final overview = state.overview;
    final exercise = state.exercise;
    if (overview == null || exercise == null) return;
    final result = await _record(
      sessionId: overview.session.id,
      studentId: event.studentId,
      exercise: exercise,
      potted: event.potted,
      total: event.total,
    );
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            overview: await _refreshed(overview),
            feedback: {...state.feedback, event.studentId: value},
            refused: {...state.refused}..remove(event.studentId),
            attemptChange: null,
            attemptRefused: null,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(refused: {...state.refused, event.studentId: failure}),
        );
    }
  }

  Future<void> _onAttemptCorrected(
    RecordResultsAttemptCorrected event,
    Emitter<RecordResultsState> emit,
  ) async {
    final overview = state.overview;
    if (overview == null) return;
    final result = await _correct(
      sessionId: overview.session.id,
      attemptId: event.attemptId,
      potted: event.potted,
      total: event.total,
    );
    await _applyChange(
      emit,
      overview,
      switch (result) {
        Ok(:final value) => AttemptChange.corrected(attempt: value),
        Err() => null,
      },
      switch (result) {
        Ok() => null,
        Err(:final failure) => failure,
      },
    );
  }

  Future<void> _onAttemptDeleted(
    RecordResultsAttemptDeleted event,
    Emitter<RecordResultsState> emit,
  ) async {
    final overview = state.overview;
    if (overview == null) return;
    final result = await _delete(
      sessionId: overview.session.id,
      attemptId: event.attemptId,
    );
    await _applyChange(
      emit,
      overview,
      switch (result) {
        Ok() => const AttemptChange.deleted(),
        Err() => null,
      },
      switch (result) {
        Ok() => null,
        Err(:final failure) => failure,
      },
    );
  }

  /// Un passage a changé : la séance est relue et les retours de saisie, qui
  /// décrivaient l'état d'avant, sont effacés ; un refus est affiché tel quel.
  Future<void> _applyChange(
    Emitter<RecordResultsState> emit,
    SessionOverview overview,
    AttemptChange? change,
    Failure? refused,
  ) async {
    if (change == null) {
      emit(state.copyWith(attemptChange: null, attemptRefused: refused));
      return;
    }
    emit(
      state.copyWith(
        overview: await _refreshed(overview),
        feedback: const {},
        refused: const {},
        attemptChange: change,
        attemptRefused: null,
      ),
    );
  }

  Future<SessionOverview> _refreshed(SessionOverview current) async =>
      switch (await _overview(current.session.id)) {
        Ok(:final value) => value,
        Err() => current,
      };
}
