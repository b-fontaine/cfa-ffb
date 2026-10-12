import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : lire et valider une sauvegarde sans rien écrire, pour que
/// l'animateur voie ce qu'elle contient avant de confirmer l'import.
@injectable
class PreviewBackup {
  PreviewBackup(this._codec, this._rules);

  final BackupCodec _codec;
  final BackupRules _rules;

  Future<Result<ImportSummary>> call(String content) => runGuarded(() async {
    final snapshot = _codec.decode(content);
    await _rules.check(snapshot);
    return ImportSummary.of(snapshot);
  });
}
