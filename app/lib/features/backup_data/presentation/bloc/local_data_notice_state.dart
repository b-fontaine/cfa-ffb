part of 'local_data_notice_cubit.dart';

/// Ce que l'écran sait des données locales de l'appareil (FB7c).
@freezed
abstract class LocalDataNoticeState with _$LocalDataNoticeState {
  const factory LocalDataNoticeState({
    /// Le relevé et le repère de l'appareil sont lus.
    @Default(false) bool loaded,
    @Default(LocalDataInventory.none) LocalDataInventory inventory,

    /// Le compte connecté a dit avoir importé ses données dans le club (et le
    /// contenu de l'appareil n'a pas changé depuis). Jamais vrai sans compte.
    @Default(false) bool acknowledged,
  }) = _LocalDataNoticeState;

  const LocalDataNoticeState._();

  /// L'entrée d'export existe : des données locales sont (peut-être) là,
  /// même quand le rappel est masqué.
  bool get entryVisible => loaded && inventory.mayHoldData;

  /// Le bandeau s'affiche : des données locales existent et le compte
  /// connecté n'a pas dit les avoir importées. Il ne disparaît qu'à cette
  /// action.
  bool get visible => entryVisible && !acknowledged;
}
