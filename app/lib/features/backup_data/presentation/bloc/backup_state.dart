part of 'backup_bloc.dart';

enum BackupStatus {
  idle,
  working,
  exported,
  exportCancelled,
  previewing,
  imported,
  failure,
}

@freezed
abstract class BackupState with _$BackupState {
  const factory BackupState({
    @Default(BackupStatus.idle) BackupStatus status,

    /// Faux quand les données ne survivent pas à la fermeture (web sans
    /// stockage durable) : l'écran avertit et propose l'export.
    @Default(true) bool persistent,
    @Default(<String>[]) List<String> storageReasons,

    /// Fichier choisi, lu et validé, en attente de confirmation.
    String? pendingContent,
    ImportSummary? preview,
    ImportSummary? imported,
    Failure? failure,
  }) = _BackupState;
}
