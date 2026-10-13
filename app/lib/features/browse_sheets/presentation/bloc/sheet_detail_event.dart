part of 'sheet_detail_bloc.dart';

@freezed
sealed class SheetDetailEvent with _$SheetDetailEvent {
  const factory SheetDetailEvent.started({
    required SheetId sheetId,
    @Default(Audience.children) Audience audience,
  }) = SheetDetailStarted;

  /// Relance la lecture de la même séance après un échec.
  const factory SheetDetailEvent.retried() = SheetDetailRetried;

  const factory SheetDetailEvent.audienceChanged({required Audience audience}) =
      SheetDetailAudienceChanged;
}
