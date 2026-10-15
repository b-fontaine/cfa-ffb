import 'package:billard_cfa/features/backup_data/domain/backup_marker.dart';

/// Rappel de sauvegarde (R6) : rien à signaler, ou la raison de rappeler.
sealed class BackupReminder {
  const BackupReminder();

  /// Règle pure. Pas de rappel tant qu'aucun passage n'a été saisi ; sinon
  /// sauvegarde ancienne ([staleAfterDays] jours révolus ou plus, réglable :
  /// `RulesConfig.backupReminderDays`), puis passages saisis
  /// depuis la dernière sauvegarde, puis aucune sauvegarde jamais faite.
  factory BackupReminder.evaluate({
    required DateTime now,
    required int attemptCount,
    required BackupMarker? last,
    required int staleAfterDays,
  }) {
    if (attemptCount <= 0) return const NoBackupReminder();
    if (last == null) return const NeverBackedUp();
    final days = _daysBetween(last.exportedAt, now);
    if (days >= staleAfterDays) return StaleBackup(days);
    final entered = attemptCount - last.attemptCount;
    if (entered > 0) return NewPassesSinceBackup(entered);
    return const NoBackupReminder();
  }

  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

/// Rien à signaler.
final class NoBackupReminder extends BackupReminder {
  const NoBackupReminder();
}

/// Des passages sont saisis et aucune sauvegarde n'a jamais été faite.
final class NeverBackedUp extends BackupReminder {
  const NeverBackedUp();
}

/// La dernière sauvegarde date de [days] jours.
final class StaleBackup extends BackupReminder {
  const StaleBackup(this.days);

  final int days;
}

/// [count] passages ont été saisis depuis la dernière sauvegarde.
final class NewPassesSinceBackup extends BackupReminder {
  const NewPassesSinceBackup(this.count);

  final int count;
}
