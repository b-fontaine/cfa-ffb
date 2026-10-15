import 'package:billard_cfa/features/manage_settings/domain/settings_field.dart';
import 'package:billard_cfa/features/manage_settings/presentation/bloc/settings_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire des réglages du club : un compteur par réglage, regroupés par
/// thème. Rien n'est appliqué avant « Enregistrer » ; « Rétablir » demande
/// une confirmation. États en bleu-tapis, aucun rouge (ADR 0010).
class SettingsForm extends StatelessWidget {
  const SettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final draft = state.draft;
        final failure = state.failure;
        if (draft == null) {
          if (failure == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ErrorView(
            message: failureMessage(l10n, failure),
            onRetry: () =>
                context.read<SettingsBloc>().add(const SettingsEvent.started()),
          );
        }
        final bloc = context.read<SettingsBloc>();
        final busy = state.status == SettingsStatus.saving;
        CounterField counter(
          SettingsField field,
          String label,
          String less,
          String more,
        ) => CounterField(
          label: label,
          value: field.read(draft),
          min: field.min,
          max: field.max,
          step: field.step,
          decreaseTooltip: less,
          increaseTooltip: more,
          onChanged: (value) =>
              bloc.add(SettingsEvent.changed(field: field, value: value)),
        );
        final status = switch (state.status) {
          SettingsStatus.saved => l10n.settingsSaved,
          SettingsStatus.reset => l10n.settingsResetDone,
          _ when state.isDirty => l10n.settingsUnsaved,
          _ => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.settingsIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: l10n.settingsSectionValidation,
              child: counter(
                SettingsField.passesRequired,
                l10n.settingsPassesRequired,
                l10n.settingsPassesRequiredLess,
                l10n.settingsPassesRequiredMore,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: l10n.settingsSectionAlerts,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  counter(
                    SettingsField.alertThreshold,
                    l10n.settingsAlertThreshold,
                    l10n.settingsAlertThresholdLess,
                    l10n.settingsAlertThresholdMore,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  counter(
                    SettingsField.recallStaleSessions,
                    l10n.settingsRecallStale,
                    l10n.settingsRecallStaleLess,
                    l10n.settingsRecallStaleMore,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  counter(
                    SettingsField.groupFailureSharePercent,
                    l10n.settingsFailureShare,
                    l10n.settingsFailureShareLess,
                    l10n.settingsFailureShareMore,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: l10n.settingsSectionBackup,
              child: counter(
                SettingsField.backupReminderDays,
                l10n.settingsBackupDays,
                l10n.settingsBackupDaysLess,
                l10n.settingsBackupDaysMore,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (failure != null) ...[
              Semantics(
                liveRegion: true,
                child: AppAlert(
                  level: AlertLevel.attention,
                  message: failureMessage(l10n, failure),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (status != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            FilledButton(
              onPressed: busy || !state.isDirty
                  ? null
                  : () => bloc.add(const SettingsEvent.saveRequested()),
              child: Text(l10n.settingsSave),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: busy ? null : () => _confirmReset(context, bloc),
              child: Text(l10n.settingsReset),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context, SettingsBloc bloc) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.settingsResetTitle,
      message: l10n.settingsResetMessage,
    );
    if (confirmed) bloc.add(const SettingsEvent.resetConfirmed());
  }
}
