import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_actions.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_choices.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_parts.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/import_report_text.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/role_labels.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le guide « Migrer mes données locales » : trois étapes courtes et la
/// mention que le fichier peut contenir des données d'enfants.
class ClubImportGuide extends StatelessWidget {
  const ClubImportGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.clubImportGuideTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.clubImportGuideStep1),
            Text(l10n.clubImportGuideStep2),
            Text(l10n.clubImportGuideStep3),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.clubImportPrivacyNote, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Étape 1 : choisir le fichier (formats 1 à 5).
class ClubImportFileStep extends StatelessWidget {
  const ClubImportFileStep({
    required this.state,
    required this.actions,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ImportStepFrame(
      state: state,
      title: l10n.clubImportFileTitle,
      children: [
        const ClubImportGuide(),
        if (state.busy)
          Semantics(
            liveRegion: state.live == ImportLive.reading,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.clubImportReading)),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: state.busy || !state.online ? null : actions.onPick,
          icon: const Icon(Icons.upload_file),
          label: Text(l10n.clubImportPick),
        ),
      ],
    );
  }
}

/// Étape 2 : le rapport d'intégrité (compteurs par catégorie, problèmes
/// localisés sans donnée d'enfant). L'import est bloqué tant qu'il y a une
/// erreur bloquante.
class ClubImportReportStep extends StatelessWidget {
  const ClubImportReportStep({
    required this.state,
    required this.actions,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = state.plan;
    if (plan == null) return const SizedBox.shrink();
    final report = plan.report;
    final marker = plan.outline.marker;
    final blocked =
        plan.status == ImportStatus.blocked && !plan.awaitsSameChoices;
    final already = plan.status == ImportStatus.alreadyImported;
    return ImportStepFrame(
      state: state,
      title: l10n.clubImportReportTitle,
      children: [
        Text(
          importStatusLabel(l10n, plan.status),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (already) Text(l10n.clubImportAlreadyImported),
        if (marker != null && !already)
          Text(l10n.clubImportStarted(marker.done, marker.lots)),
        if (blocked) ...[
          ImportProblemsList(plan: plan),
          Text(l10n.clubImportReportBlocked),
        ],
        for (final warning in report.warnings)
          AppAlert(
            level: AlertLevel.attention,
            message: importWarningMessage(l10n, warning, plan),
          ),
        Semantics(
          container: true,
          label: l10n.clubImportReportCounts,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.clubImportReportCounts,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final line in importCountLines(l10n, report)) Text(line),
            ],
          ),
        ),
        if (!blocked && !already)
          for (final line in importUndecidedLines(l10n, report)) Text(line),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (!blocked && !already)
              FilledButton(
                onPressed: state.busy || !state.canContinue
                    ? null
                    : actions.onNext,
                child: Text(l10n.clubImportContinue),
              ),
            OutlinedButton(
              onPressed: state.busy ? null : actions.onRestart,
              child: Text(l10n.clubImportChooseOther),
            ),
          ],
        ),
      ],
    );
  }
}

/// Étape 6 : le récapitulatif avant écriture (écritures, lots, jours, rôle
/// effectif, reprise).
class ClubImportRecapStep extends StatelessWidget {
  const ClubImportRecapStep({
    required this.state,
    required this.actions,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = state.plan;
    if (plan == null) return const SizedBox.shrink();
    final resume = plan.status == ImportStatus.resumable;
    final lots = plan.lots.length - plan.startLot;
    return ImportStepFrame(
      state: state,
      title: l10n.clubImportRecapTitle,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.clubImportRecapWrites(plan.remainingWrites)),
            Text(l10n.clubImportRecapLots(lots)),
            Text(l10n.clubImportRecapDays(plan.daysNeeded)),
            if (state.role != null)
              Text(l10n.clubImportRecapRole(state.role!.label(l10n))),
            if (resume)
              Text(
                l10n.clubImportRecapResume(plan.startLot + 1, plan.lots.length),
              ),
          ],
        ),
        for (final warning in plan.report.warnings)
          AppAlert(
            level: AlertLevel.attention,
            message: importWarningMessage(l10n, warning, plan),
          ),
        Text(l10n.clubImportRecapIrreversible),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              onPressed: state.busy || !plan.isRunnable || !state.online
                  ? null
                  : actions.onStart,
              child: Text(
                resume ? l10n.clubImportStartResume : l10n.clubImportStart,
              ),
            ),
            TextButton(
              onPressed: state.busy ? null : actions.onBack,
              child: Text(l10n.clubImportBack),
            ),
          ],
        ),
      ],
    );
  }
}

/// Étape 7 : l'exécution. L'avancement est une région vive (« lot n sur N ») ;
/// la pause du plafond du jour, la coupure du réseau et l'arrêt demandé ne sont
/// **pas** des erreurs rouges ; un refus du serveur est dit sobrement.
class ClubImportRunStep extends StatelessWidget {
  const ClubImportRunStep({
    required this.state,
    required this.actions,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final run = state.run;
    final done = state.doneLots;
    final total = state.totalLots;
    final progress = l10n.clubImportProgress(done, total);
    final failure = state.runFailure;
    final outcomeLive = state.live == ImportLive.outcome;
    return ImportStepFrame(
      state: state,
      title: l10n.clubImportRunTitle,
      children: [
        Semantics(
          liveRegion: state.live == ImportLive.progress,
          label: progress,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(progress),
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(
                  value: total == 0 ? null : done / total,
                ),
              ],
            ),
          ),
        ),
        switch (run) {
          ClubImportRun.running => OutlinedButton(
            onPressed: actions.onCancel,
            child: Text(l10n.clubImportCancel),
          ),
          ClubImportRun.cancelling => Semantics(
            liveRegion: outcomeLive,
            child: Text(l10n.clubImportCancelling),
          ),
          ClubImportRun.cancelled => _Outcome(
            live: outcomeLive,
            level: AlertLevel.attention,
            message: l10n.clubImportCancelled(done, total),
            actions: [
              FilledButton(
                onPressed: actions.onResume,
                child: Text(l10n.clubImportResume),
              ),
              TextButton(
                onPressed: actions.onFinish,
                child: Text(l10n.clubImportFinish),
              ),
            ],
          ),
          ClubImportRun.paused => _Outcome(
            live: outcomeLive,
            level: AlertLevel.attention,
            title: l10n.clubImportPausedTitle,
            message: l10n.clubImportPausedBody(done, total),
            actions: [
              FilledButton(
                onPressed: actions.onFinish,
                child: Text(l10n.clubImportFinish),
              ),
            ],
          ),
          ClubImportRun.interrupted => _Outcome(
            live: outcomeLive,
            level: AlertLevel.attention,
            message: l10n.clubImportInterrupted,
            actions: [
              FilledButton(
                onPressed: state.busy ? null : actions.onResume,
                child: Text(l10n.clubImportResume),
              ),
            ],
          ),
          ClubImportRun.planChanged => _Outcome(
            live: outcomeLive,
            level: AlertLevel.persistent,
            message: l10n.clubImportPlanChanged,
            actions: [
              FilledButton(
                onPressed: actions.onRestart,
                child: Text(l10n.clubImportChooseOther),
              ),
            ],
          ),
          ClubImportRun.failed => _Outcome(
            live: outcomeLive,
            level: AlertLevel.persistent,
            message:
                failure is ServiceFailure &&
                    failure.code == ServiceFailureCode.denied
                ? l10n.clubImportRuleRefused
                : failure == null
                ? l10n.failGeneric
                : failureMessage(l10n, failure),
            actions: [
              FilledButton(
                onPressed: state.busy ? null : actions.onResume,
                child: Text(l10n.clubImportRetry),
              ),
              TextButton(
                onPressed: actions.onFinish,
                child: Text(l10n.clubImportFinish),
              ),
            ],
          ),
          null => const SizedBox.shrink(),
        },
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.live,
    required this.level,
    required this.message,
    required this.actions,
    this.title,
  });

  /// Seule l'alerte est annoncée : les boutons restent hors de la région vive.
  final bool live;
  final AlertLevel level;
  final String? title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: live,
        child: AppAlert(
          level: level,
          message: title == null ? message : '$title\n$message',
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: actions,
      ),
    ],
  );
}

/// Étape 8 : la fin, un résumé par catégorie, sans donnée personnelle.
class ClubImportDoneStep extends StatelessWidget {
  const ClubImportDoneStep({
    required this.state,
    required this.actions,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = state.plan;
    return ImportStepFrame(
      state: state,
      title: l10n.clubImportDoneTitle,
      children: [
        if (plan != null) ...[
          Text(l10n.clubImportDoneBody(plan.totalWrites, plan.lots.length)),
          for (final line in importCountLines(l10n, plan.report)) Text(line),
        ],
        Text(l10n.clubImportDoneNote),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            onPressed: actions.onFinish,
            child: Text(l10n.clubImportFinish),
          ),
        ),
      ],
    );
  }
}

/// L'écran d'import : le rôle effectif, le réseau, l'échec éventuel et
/// l'étape courante.
class ClubImportView extends StatelessWidget {
  const ClubImportView({required this.state, required this.actions, super.key});

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final role = state.role;
    final failure = state.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (role != null) ...[
          Text(l10n.clubImportRoleLine(role.label(l10n))),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!state.online) ...[
          Semantics(
            liveRegion: state.live == ImportLive.offline,
            child: AppAlert(
              level: AlertLevel.attention,
              message: l10n.clubImportOffline,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (failure != null) ...[
          AppAlert(
            level: AlertLevel.persistent,
            message: failureMessage(l10n, failure),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        switch (state.step) {
          ClubImportStep.file => ClubImportFileStep(
            state: state,
            actions: actions,
          ),
          ClubImportStep.report => ClubImportReportStep(
            state: state,
            actions: actions,
          ),
          ClubImportStep.groups => ClubImportGroupsStep(
            state: state,
            actions: actions,
          ),
          ClubImportStep.loose => ClubImportLooseStep(
            state: state,
            actions: actions,
          ),
          ClubImportStep.confirmations => ClubImportConfirmStep(
            state: state,
            actions: actions,
          ),
          ClubImportStep.recap => ClubImportRecapStep(
            state: state,
            actions: actions,
          ),
          ClubImportStep.running => ClubImportRunStep(
            state: state,
            actions: actions,
          ),
          ClubImportStep.finished => ClubImportDoneStep(
            state: state,
            actions: actions,
          ),
        },
      ],
    );
  }
}
