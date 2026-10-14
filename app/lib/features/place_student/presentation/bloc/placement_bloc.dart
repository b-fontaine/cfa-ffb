import 'package:billard_cfa/features/place_student/domain/mark_block_acquired.dart';
import 'package:billard_cfa/features/place_student/domain/revoke_block_acquired.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'placement_bloc.freezed.dart';
part 'placement_event.dart';
part 'placement_state.dart';

/// Positionnement d'un élève depuis sa fiche : marquer un bloc acquis ou
/// retirer l'acquis (ADR 0008). La confirmation est demandée par l'écran.
@injectable
class PlacementBloc extends Bloc<PlacementEvent, PlacementState> {
  PlacementBloc(this._mark, this._revoke, this._clock)
    : super(const PlacementState()) {
    on<PlacementMarkRequested>(_onMarkRequested);
    on<PlacementRevokeRequested>(_onRevokeRequested);
  }

  final MarkBlockAcquired _mark;
  final RevokeBlockAcquired _revoke;
  final Clock _clock;

  Future<void> _onMarkRequested(
    PlacementMarkRequested event,
    Emitter<PlacementState> emit,
  ) async {
    emit(
      PlacementState(
        status: PlacementStatus.working,
        action: PlacementAction.mark,
        blockId: event.blockId,
      ),
    );
    final result = await _mark(
      studentId: event.studentId,
      blockId: event.blockId,
      date: event.date,
      today: _clock.today(),
    );
    _conclude(emit, PlacementAction.mark, event.blockId, result);
  }

  Future<void> _onRevokeRequested(
    PlacementRevokeRequested event,
    Emitter<PlacementState> emit,
  ) async {
    emit(
      PlacementState(
        status: PlacementStatus.working,
        action: PlacementAction.revoke,
        blockId: event.blockId,
      ),
    );
    final result = await _revoke(
      studentId: event.studentId,
      blockId: event.blockId,
    );
    _conclude(emit, PlacementAction.revoke, event.blockId, result);
  }

  void _conclude(
    Emitter<PlacementState> emit,
    PlacementAction action,
    String blockId,
    Result<Object?> result,
  ) {
    switch (result) {
      case Ok():
        emit(
          PlacementState(
            status: PlacementStatus.done,
            action: action,
            blockId: blockId,
          ),
        );
      case Err(:final failure):
        emit(
          PlacementState(
            status: PlacementStatus.refused,
            action: action,
            blockId: blockId,
            failure: failure,
          ),
        );
    }
  }
}
