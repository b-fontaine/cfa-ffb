import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'plan_next_session_cubit.freezed.dart';

@freezed
sealed class PlanNextSessionState with _$PlanNextSessionState {
  /// Rien n'est encore planifié.
  const factory PlanNextSessionState.idle() = PlanNextIdle;

  const factory PlanNextSessionState.planning() = PlanNextPlanning;

  const factory PlanNextSessionState.planned(Session session) = PlanNextPlanned;

  /// La planification a été refusée ; [failure] est le motif métier.
  const factory PlanNextSessionState.failed(Failure failure) = PlanNextFailed;
}

/// « Planifier » depuis le bilan : crée directement une séance planifiée
/// datée et liée au groupe.
@injectable
class PlanNextSessionCubit extends Cubit<PlanNextSessionState> {
  PlanNextSessionCubit(this._plan) : super(const PlanNextSessionState.idle());

  final PlanSession _plan;

  Future<void> plan({
    required String title,
    required DateTime date,
    required SheetId? sheetId,
    required GroupId groupId,
  }) async {
    // Un second appui, pendant ou après la planification, ne crée rien de plus.
    if (state is PlanNextPlanning || state is PlanNextPlanned) return;
    emit(const PlanNextSessionState.planning());
    try {
      final session = await _plan(
        title: title,
        date: date,
        sheetId: sheetId,
        groupId: groupId,
      );
      if (!isClosed) emit(PlanNextSessionState.planned(session));
    } on InvalidSessionTitle {
      if (!isClosed) {
        emit(
          const PlanNextSessionState.failed(
            InvariantViolation(InvariantCode.blankName),
          ),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) emit(PlanNextSessionState.failed(failure));
    }
  }
}
