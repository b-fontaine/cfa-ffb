import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'run_presentation_cubit.freezed.dart';

enum PresentationStatus { loading, ready, notFound, failure }

@freezed
abstract class RunPresentationState with _$RunPresentationState {
  const factory RunPresentationState({
    @Default(PresentationStatus.loading) PresentationStatus status,
    RunPlan? plan,
    Failure? failure,
    @Default(0) int step,
  }) = _RunPresentationState;
}

/// Mode présentation : montre aux élèves l'illustration d'une étape, sans
/// notes ni notation. Résout lui-même son déroulé (route de premier niveau,
/// hors du shell) ; l'étape est locale à la présentation. Elle s'ouvre sur
/// l'étape demandée si elle a quelque chose à montrer, sinon sur la
/// prochaine qui en a une.
@injectable
class RunPresentationCubit extends Cubit<RunPresentationState> {
  RunPresentationCubit(this._resolve) : super(const RunPresentationState());

  final ResolveRunPlan _resolve;

  /// Les arguments de la dernière ouverture, pour [retry].
  ({SheetId sheetId, Audience? audience, String? sessionId, int step})? _last;

  /// Relance la lecture après un échec, avec les mêmes arguments.
  Future<void> retry() async {
    final last = _last;
    if (last == null) return;
    await started(
      sheetId: last.sheetId,
      audience: last.audience,
      sessionId: last.sessionId,
      step: last.step,
    );
  }

  Future<void> started({
    required SheetId sheetId,
    Audience? audience,
    String? sessionId,
    int step = 0,
  }) async {
    _last = (
      sheetId: sheetId,
      audience: audience,
      sessionId: sessionId,
      step: step,
    );
    emit(const RunPresentationState());
    final result = await _resolve(
      sheetId,
      audience: audience,
      sessionId: sessionId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          RunPresentationState(
            status: PresentationStatus.ready,
            plan: value,
            step: value.presentationStart(step),
          ),
        );
      case Err(failure: NotFound()):
        emit(const RunPresentationState(status: PresentationStatus.notFound));
      case Err(:final failure):
        emit(
          RunPresentationState(
            status: PresentationStatus.failure,
            failure: failure,
          ),
        );
    }
  }

  /// Prochaine étape qui a quelque chose à montrer ; sans effet s'il n'y en
  /// a plus.
  void next() => _move(1);

  /// Étape précédente qui a quelque chose à montrer.
  void previous() => _move(-1);

  void _move(int direction) {
    final plan = state.plan;
    if (plan == null) return;
    var index = state.step + direction;
    while (index >= 0 && index < plan.stepCount) {
      if (plan.isPresentable(plan.steps[index])) {
        emit(state.copyWith(step: index));
        return;
      }
      index += direction;
    }
  }
}
