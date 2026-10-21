import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/shared/lib/failure.dart';

/// Un fichier de sauvegarde de la base locale, prêt à enregistrer, avec ce
/// qu'il contient (relu du fichier produit, pas de la base).
class LocalBackup {
  const LocalBackup({required this.content, required this.summary});

  final String content;
  final ImportSummary summary;
}

/// Cas d'usage (FB7c) : exporter la base **locale** (drift) d'un build qui
/// lit le club sur Firestore, **en lecture seule** : le même codec que
/// l'export du club (format inchangé, relu par l'import dans le club), les
/// dépôts locaux ne sont lus que par leurs `all()`.
///
/// **La date du fichier est celle de la dernière modification réelle de la
/// base** (`LocalDataInventory.lastModified`, relevée au démarrage), jamais
/// l'heure de l'export : l'import dans le club s'en sert pour savoir si le
/// fichier peut contenir des élèves que le club a effacés depuis (saison close
/// à cette date ou après). Un fichier exporté après une clôture faite dans le
/// club, d'une base restée telle quelle, doit rester « antérieur » à cette
/// clôture. Une base sans aucun horodatage donne un fichier **sans date**,
/// traité par l'import comme potentiellement périmé (ADR 0019, ADR 0024).
///
/// Rien n'est enregistré ici : l'écran montre d'abord [LocalBackup.summary]
/// (un fichier vide ne s'enregistre pas, voir `LocalExportCubit`).
class ExportLocalBackup {
  ExportLocalBackup(this._reader, this._settings, this._codec, this._probe);

  final BackupSnapshotReader _reader;
  final SettingsRepository _settings;
  final BackupCodec _codec;
  final LocalDataProbe _probe;

  Future<Result<LocalBackup>> call() => runGuarded(() async {
    final inventory = await _probe.inspect();
    final snapshot = await _reader.read(await _settings.load());
    final content = _codec.encode(snapshot, exportedAt: inventory.lastModified);
    // Les compteurs sont ceux du fichier relu : ce que l'animateur voit est
    // ce que le fichier contient.
    return LocalBackup(
      content: content,
      summary: ImportSummary.of(_codec.decode(content)),
    );
  });
}
