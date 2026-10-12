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
/// élève, retour immédiat (objectif, validation, alerte).
@injectable
class RecordResultsBloc extends Bloc<RecordResultsEvent, RecordResultsState> {
  RecordResultsBloc(this._overview, this._record)
    : super(const RecordResultsState()) {
    on<RecordResultsStarted>(_onStarted);
    on<RecordResultsExerciseSelected>(_onExerciseSelected);
    on<RecordResultsPassSubmitted>(_onPassSubmitted);
  }

  final GetSessionOverview _overview;
  final RecordAttempt _record;

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
        emit(
          RecordResultsState(
            status: RecordStatus.ready,
            overview: value,
            exercise: (block?.exercises ?? value.catalogue.exercises).first.ref,
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
        final refreshed = await _overview(overview.session.id);
        emit(
          state.copyWith(
            overview: switch (refreshed) {
              Ok(:final value) => value,
              Err() => overview,
            },
            feedback: {...state.feedback, event.studentId: value},
            refused: {...state.refused}..remove(event.studentId),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(refused: {...state.refused, event.studentId: failure}),
        );
    }
  }
}
