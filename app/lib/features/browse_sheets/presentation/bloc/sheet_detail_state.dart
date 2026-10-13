part of 'sheet_detail_bloc.dart';

enum SheetDetailStatus { loading, ready, notFound, failure }

@freezed
abstract class SheetDetailState with _$SheetDetailState {
  const factory SheetDetailState({
    @Default(SheetDetailStatus.loading) SheetDetailStatus status,
    @Default(Audience.children) Audience audience,

    /// La séance demandée (pour relancer la lecture).
    SheetId? sheetId,
    SheetDetail? detail,
    Failure? failure,
  }) = _SheetDetailState;
}
