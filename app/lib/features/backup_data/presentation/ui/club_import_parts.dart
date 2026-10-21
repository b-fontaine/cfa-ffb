import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_actions.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/import_report_text.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Ce que le lecteur d'écran annonce **seul** à un instant donné : une seule
/// région vive polie à la fois, jamais plusieurs qui se déclenchent ensemble
/// au changement d'étape. Par priorité : le réseau absent, puis l'issue de
/// l'exécution ou son avancement, puis la lecture du fichier, puis le titre de
/// l'étape.
enum ImportLive { offline, progress, outcome, reading, title }

extension ImportLiveOf on ClubImportState {
  ImportLive get live {
    if (!online) return ImportLive.offline;
    if (step == ClubImportStep.running) {
      return run == null || run == ClubImportRun.running
          ? ImportLive.progress
          : ImportLive.outcome;
    }
    if (step == ClubImportStep.file && busy) return ImportLive.reading;
    return ImportLive.title;
  }
}

/// Le cadre commun d'une étape : un titre (en-tête sémantique ; annoncé au
/// changement d'étape quand rien d'autre n'est annoncé, voir [ImportLive])
/// puis son contenu.
class ImportStepFrame extends StatelessWidget {
  const ImportStepFrame({
    required this.state,
    required this.title,
    required this.children,
    super.key,
  });

  final ClubImportState state;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        liveRegion: state.live == ImportLive.title,
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      for (final child in children) ...[
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ],
  );
}

/// Les problèmes du plan courant, localisés, sans prénom ni donnée d'enfant.
class ImportProblemsList extends StatelessWidget {
  const ImportProblemsList({required this.plan, super.key});

  final ClubImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = plan.report;
    if (report.problems.isEmpty) return const SizedBox.shrink();
    final shown = importFirstProblemLines(l10n, report);
    final rest = report.problems.length - shown.length;
    return AppAlert(
      level: AlertLevel.persistent,
      message: [
        ...shown,
        if (rest > 0) l10n.clubImportReportMore(rest),
      ].join('\n'),
    );
  }
}

/// « Retour » et « Continuer » d'une étape ; « Continuer » est inerte tant que
/// le plan interdit d'avancer (choix manquant, confirmation, problème).
class ImportNav extends StatelessWidget {
  const ImportNav({required this.state, required this.actions, super.key});

  final ClubImportState state;
  final ClubImportActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton(
          onPressed: state.busy || !state.canContinue ? null : actions.onNext,
          child: Text(l10n.clubImportContinue),
        ),
        TextButton(
          onPressed: state.busy ? null : actions.onBack,
          child: Text(l10n.clubImportBack),
        ),
      ],
    );
  }
}
