import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'sheet_catalogue_bloc.freezed.dart';
part 'sheet_catalogue_event.dart';
part 'sheet_catalogue_state.dart';

/// Le catalogue de séances groupé par technique, avec les filtres « à
/// valider » et « jeux à valider » (aucune donnée stockée : le filtre est un
/// état d'écran).
@injectable
class SheetCatalogueBloc
    extends Bloc<SheetCatalogueEvent, SheetCatalogueState> {
  SheetCatalogueBloc(this._listSheets) : super(const SheetCatalogueState()) {
    on<SheetCatalogueStarted>(_onStarted);
    on<SheetCatalogueReviewFilterSelected>(_onFilterSelected);
  }

  final ListSheets _listSheets;

  Future<void> _onStarted(
    SheetCatalogueStarted event,
    Emitter<SheetCatalogueState> emit,
  ) async {
    emit(const SheetCatalogueState());
    switch (await _listSheets()) {
      case Ok(:final value):
        emit(
          state.copyWith(status: SheetCatalogueStatus.ready, catalogue: value),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SheetCatalogueStatus.failure,
            failure: failure,
          ),
        );
    }
  }

  void _onFilterSelected(
    SheetCatalogueReviewFilterSelected event,
    Emitter<SheetCatalogueState> emit,
  ) {
    final same = state.reviewFilter == event.filter;
    emit(
      state.copyWith(
        reviewFilter: same ? SheetReviewFilter.none : event.filter,
      ),
    );
  }
}
