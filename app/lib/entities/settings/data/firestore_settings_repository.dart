import 'package:billard_cfa/entities/settings/data/settings_document.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Réglages du club actif dans `clubs/{c}/settings/main` (ADR 0024, A5) : un
/// document par club, lu par tous les membres, écrit par le directeur et
/// l'administrateur (règles). Choisi par `DataBackend.firestore`.
///
/// Sans document, les valeurs par défaut s'appliquent (comme la ligne SQL
/// absente) ; `reset` supprime le document.
class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository(this._club);

  final ClubStore _club;

  @override
  Future<ClubSettings> load() => guardStore(() async {
    final document = await _club.get(_club.paths.settings);
    return document == null
        ? ClubSettings.defaults
        : SettingsDocument.decode(document);
  });

  @override
  Future<void> save(ClubSettings settings) => guardStore(
    () => _club.commit([
      SetOp(_club.paths.settings, SettingsDocument.encode(settings)),
    ]),
  );

  @override
  Future<void> reset() =>
      guardStore(() => _club.commit([DeleteOp(_club.paths.settings)]));
}
