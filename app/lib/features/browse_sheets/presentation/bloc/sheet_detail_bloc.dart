import 'package:billard_cfa/features/browse_sheets/domain/get_sheet.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'sheet_detail_bloc.freezed.dart';
part 'sheet_detail_event.dart';
part 'sheet_detail_state.dart';

/// Une séance du catalogue en lecture seule ; le public affiché (enfants ou
/// adultes) est un état d'écran qui ne change que les minutes et les éléments
/// propres à un public.
@injectable
class SheetDetailBloc extends Bloc<SheetDetailEvent, SheetDetailState> {
  SheetDetailBloc(this._getSheet) : super(const SheetDetailState()) {
    on<SheetDetailStarted>(_onStarted);
    on<SheetDetailRetried>(_onRetried);
    on<SheetDetailAudienceChanged>(_onAudienceChanged);
  }

  final GetSheet _getSheet;

  Future<void> _onStarted(
    SheetDetailStarted event,
    Emitter<SheetDetailState> emit,
  ) async {
    await _load(event.sheetId, event.audience, emit);
  }

  Future<void> _onRetried(
    SheetDetailRetried event,
    Emitter<SheetDetailState> emit,
  ) async {
    final sheetId = state.sheetId;
    if (sheetId == null) return;
    await _load(sheetId, state.audience, emit);
  }

  Future<void> _load(
    SheetId sheetId,
    Audience audience,
    Emitter<SheetDetailState> emit,
  ) async {
    emit(SheetDetailState(audience: audience, sheetId: sheetId));
    switch (await _getSheet(sheetId)) {
      case Ok(:final value):
        emit(state.copyWith(status: SheetDetailStatus.ready, detail: value));
      case Err(failure: NotFound()):
        emit(state.copyWith(status: SheetDetailStatus.notFound));
      case Err(:final failure):
        emit(
          state.copyWith(status: SheetDetailStatus.failure, failure: failure),
        );
    }
  }

  void _onAudienceChanged(
    SheetDetailAudienceChanged event,
    Emitter<SheetDetailState> emit,
  ) {
    emit(state.copyWith(audience: event.audience));
  }
}
