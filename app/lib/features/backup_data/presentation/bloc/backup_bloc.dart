import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/domain/preview_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/record_backup_done.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'backup_bloc.freezed.dart';
part 'backup_event.dart';
part 'backup_state.dart';

/// Export JSON, import avec prévisualisation et confirmation, état du
/// stockage (avertissement si la persistance est volatile).
@injectable
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  BackupBloc(
    this._export,
    this._recordDone,
    this._preview,
    this._import,
    this._files,
    this._storage,
  ) : super(const BackupState()) {
    on<BackupStarted>(_onStarted);
    on<BackupExportRequested>(_onExport);
    on<BackupImportRequested>(_onImportRequested);
    on<BackupImportConfirmed>(_onImportConfirmed);
    on<BackupImportCancelled>(_onImportCancelled);
  }

  final ExportBackup _export;
  final RecordBackupDone _recordDone;
  final PreviewBackup _preview;
  final ImportBackup _import;
  final BackupFiles _files;
  final StorageStatus _storage;

  void _onStarted(BackupStarted event, Emitter<BackupState> emit) {
    emit(
      BackupState(
        persistent: _storage.implementation.persistent,
        storageReasons: _storage.degradationReasons,
      ),
    );
  }

  Future<void> _onExport(
    BackupExportRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(status: BackupStatus.working, failure: null));
    switch (await _export()) {
      case Ok(:final value):
        final saved = await _files.save(
          fileName: event.fileName,
          content: value,
        );
        // Un fichier enregistré = une sauvegarde faite (rappel U6) ; l'échec
        // de cette mémoire ne fait pas échouer l'export.
        if (saved) await _recordDone();
        emit(
          state.copyWith(
            status: saved
                ? BackupStatus.exported
                : BackupStatus.exportCancelled,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: BackupStatus.failure, failure: failure));
    }
  }

  Future<void> _onImportRequested(
    BackupImportRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(status: BackupStatus.working, failure: null));
    final content = await _files.pick();
    if (content == null) {
      emit(state.copyWith(status: BackupStatus.idle));
      return;
    }
    switch (await _preview(content)) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: BackupStatus.previewing,
            pendingContent: content,
            preview: value,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: BackupStatus.failure, failure: failure));
    }
  }

  Future<void> _onImportConfirmed(
    BackupImportConfirmed event,
    Emitter<BackupState> emit,
  ) async {
    final content = state.pendingContent;
    if (content == null) return;
    emit(state.copyWith(status: BackupStatus.working));
    switch (await _import(content)) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: BackupStatus.imported,
            pendingContent: null,
            preview: null,
            imported: value,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: BackupStatus.failure,
            pendingContent: null,
            preview: null,
            failure: failure,
          ),
        );
    }
  }

  void _onImportCancelled(
    BackupImportCancelled event,
    Emitter<BackupState> emit,
  ) {
    emit(
      state.copyWith(
        status: BackupStatus.idle,
        pendingContent: null,
        preview: null,
      ),
    );
  }
}
