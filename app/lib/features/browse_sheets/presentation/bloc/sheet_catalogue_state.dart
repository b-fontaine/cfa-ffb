part of 'sheet_catalogue_bloc.dart';

enum SheetCatalogueStatus { loading, ready, failure }

@freezed
abstract class SheetCatalogueState with _$SheetCatalogueState {
  const factory SheetCatalogueState({
    @Default(SheetCatalogueStatus.loading) SheetCatalogueStatus status,
    SheetCatalogue? catalogue,
    @Default(SheetReviewFilter.none) SheetReviewFilter reviewFilter,
    Failure? failure,
  }) = _SheetCatalogueState;

  const SheetCatalogueState._();

  /// Le catalogue à afficher, réduit selon le filtre actif.
  SheetCatalogue? get visible => catalogue?.filtered(reviewFilter);
}
