import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:injectable/injectable.dart';

/// Fichiers de sauvegarde des tests et scénarios BDD : le dernier fichier
/// enregistré est conservé, et le prochain choix est programmable.
@LazySingleton(as: BackupFiles, env: [Environment.test])
class InMemoryBackupFiles implements BackupFiles {
  /// Dernier fichier enregistré ; `null` avant tout enregistrement.
  ({String fileName, String content})? lastSaved;

  /// Texte rendu par le prochain [pick] (puis `null`).
  String? nextPick;

  /// Simule l'annulation de la boîte d'enregistrement.
  bool cancelSave = false;

  @override
  Future<bool> save({required String fileName, required String content}) async {
    if (cancelSave) return false;
    lastSaved = (fileName: fileName, content: content);
    return true;
  }

  @override
  Future<String?> pick() async {
    final text = nextPick;
    nextPick = null;
    return text;
  }
}
