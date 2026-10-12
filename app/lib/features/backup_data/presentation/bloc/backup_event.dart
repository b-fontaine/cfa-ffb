part of 'backup_bloc.dart';

@freezed
sealed class BackupEvent with _$BackupEvent {
  const factory BackupEvent.started() = BackupStarted;

  /// [fileName] : nom proposé pour le fichier (texte localisé).
  const factory BackupEvent.exportRequested({required String fileName}) =
      BackupExportRequested;

  const factory BackupEvent.importRequested() = BackupImportRequested;

  const factory BackupEvent.importConfirmed() = BackupImportConfirmed;

  const factory BackupEvent.importCancelled() = BackupImportCancelled;
}
