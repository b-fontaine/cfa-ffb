part of 'sheet_catalogue_bloc.dart';

@freezed
sealed class SheetCatalogueEvent with _$SheetCatalogueEvent {
  const factory SheetCatalogueEvent.started() = SheetCatalogueStarted;

  /// Choisit un filtre « à valider » ; choisir celui déjà actif le retire.
  const factory SheetCatalogueEvent.reviewFilterSelected({
    required SheetReviewFilter filter,
  }) = SheetCatalogueReviewFilterSelected;
}
