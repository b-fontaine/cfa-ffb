import 'package:billard_cfa/features/backup_data/domain/backup_reminder.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Bandeau de rappel de sauvegarde (R6) : non bloquant, avec une action qui
/// mène à l'écran de sauvegarde ; absent quand la règle ne dit rien.
class BackupReminderBanner extends StatelessWidget {
  const BackupReminderBanner({
    required this.reminder,
    required this.onBackup,
    super.key,
  });

  final BackupReminder reminder;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (reminder) {
      NoBackupReminder() => null,
      NeverBackedUp() => l10n.backupReminderNever,
      StaleBackup(:final days) => l10n.backupReminderStale(days),
      NewPassesSinceBackup(:final count) => l10n.backupReminderNewPasses(count),
    };
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppAlert(level: AlertLevel.attention, message: message),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonal(
              onPressed: onBackup,
              child: Text(l10n.backupReminderAction),
            ),
          ),
        ],
      ),
    );
  }
}
