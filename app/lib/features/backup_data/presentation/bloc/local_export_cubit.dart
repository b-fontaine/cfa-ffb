import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/export_local_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'local_export_cubit.freezed.dart';
part 'local_export_state.dart';

/// L'export de la base locale (FB7c) : lit, **montre le contenu du fichier**,
/// puis enregistre sur demande. Un fichier vide ne s'enregistre pas.
@injectable
class LocalExportCubit extends Cubit<LocalExportState> {
  LocalExportCubit(this._export, this._files, this._probe)
    : super(const LocalExportState());

  final ExportLocalBackup _export;
  final BackupFiles _files;
  final LocalDataProbe _probe;

  String? _content;

  /// Lit la base locale (lecture seule) et prépare le fichier.
  Future<void> prepare() async {
    _content = null;
    emit(const LocalExportState());
    LocalDataInventory found;
    try {
      found = await _probe.inspect();
    } on Object {
      found = const LocalDataInventory(state: LocalStoreState.unreadable);
    }
    switch (found.state) {
      case LocalStoreState.newerSchema:
        emit(const LocalExportState(status: LocalExportStatus.newerSchema));
        return;
      case LocalStoreState.absent ||
          LocalStoreState.present ||
          LocalStoreState.unreadable:
        // `unreadable` : le relevé du démarrage a pu échouer alors que la
        // lecture par les dépôts réussit ; c'est elle qui décide (et qui
        // dit « illisible » si elle échoue aussi). « Réessayer » la refait.
        break;
    }
    try {
      switch (await _export()) {
        case Ok(:final value):
          _content = value.content;
          emit(
            LocalExportState(
              status: LocalExportStatus.ready,
              summary: value.summary,
              migrated: found.migrationPending,
            ),
          );
        case Err():
          emit(const LocalExportState(status: LocalExportStatus.unreadable));
      }
    } on Object {
      emit(const LocalExportState(status: LocalExportStatus.unreadable));
    }
  }

  /// Enregistre le fichier prêt sous [fileName]. Sans contenu, ne fait rien.
  Future<void> save({required String fileName}) async {
    final content = _content;
    if (content == null || !state.canSave) return;
    final summary = state.summary;
    bool saved;
    try {
      saved = await _files.save(fileName: fileName, content: content);
    } on Object {
      emit(const LocalExportState(status: LocalExportStatus.saveFailed));
      return;
    }
    emit(
      LocalExportState(
        status: saved ? LocalExportStatus.saved : LocalExportStatus.cancelled,
        summary: summary,
        migrated: state.migrated,
      ),
    );
  }
}
