import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Réglages persistés dans SQLite (drift) : une seule ligne (`id = 1`) ; sans
/// ligne, les valeurs par défaut s'appliquent.
@LazySingleton(as: SettingsRepository, env: [Environment.prod])
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, this._clock);

  static const _rowId = 1;

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<ClubSettings> load() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.id.equals(_rowId))).getSingleOrNull();
    if (row == null) return ClubSettings.defaults;
    return ClubSettings(
      passesRequired: row.passesRequired,
      alertThreshold: row.alertThreshold,
      recallStaleSessions: row.recallStaleSessions,
      groupFailureSharePercent: row.groupFailureSharePercent,
      backupReminderDays: row.backupReminderDays,
    );
  }

  @override
  Future<void> save(ClubSettings settings) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          id: const Value(_rowId),
          passesRequired: settings.passesRequired,
          alertThreshold: settings.alertThreshold,
          recallStaleSessions: settings.recallStaleSessions,
          groupFailureSharePercent: settings.groupFailureSharePercent,
          backupReminderDays: settings.backupReminderDays,
          updatedAt: _clock.now(),
        ),
      );

  @override
  Future<void> reset() async {
    await (_db.delete(_db.appSettings)..where((t) => t.id.equals(_rowId))).go();
  }
}
