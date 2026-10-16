import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/season_closure_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/closure_choice_tile.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// L'assistant de clôture d'une saison (ADR 0019), en cinq sections lisibles
/// d'un seul tenant : récapitulatif, sauvegarde conseillée, choix par élève,
/// options, confirmation ; puis le compte rendu, sans aucun prénom.
///
/// [backupSection] est fourni par la page (l'export de sauvegarde est une
/// autre feature) ; [onSeasons] et [onHome] sont les sorties du compte rendu.
class SeasonClosureView extends StatelessWidget {
  const SeasonClosureView({
    required this.backupSection,
    required this.backupAfterSection,
    required this.onSeasons,
    required this.onHome,
    super.key,
  });

  /// L'export avant la clôture (section 2).
  final Widget backupSection;

  /// L'export après la clôture (compte rendu).
  final Widget backupAfterSection;
  final VoidCallback onSeasons;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<SeasonClosureBloc, SeasonClosureState>(
      builder: (context, state) {
        final plan = state.plan;
        final failure = state.failure;
        if (state.status == SeasonClosureStatus.loading) {
          return const SizedBox(height: 200, child: LoadingView());
        }
        if (plan == null) {
          return SizedBox(
            height: 240,
            child: ErrorView(
              message: failureMessage(l10n, failure!),
              onBack: onHome,
            ),
          );
        }
        if (state.status == SeasonClosureStatus.closed) {
          return _Done(
            state: state,
            backupAfterSection: backupAfterSection,
            onSeasons: onSeasons,
            onHome: onHome,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Recap(state: state),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: l10n.closureBackupTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.closureBackupBody),
                  const SizedBox(height: AppSpacing.sm),
                  backupSection,
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Choices(state: state),
            const SizedBox(height: AppSpacing.md),
            _Options(state: state),
            const SizedBox(height: AppSpacing.md),
            _Confirm(state: state),
          ],
        );
      },
    );
  }
}

class _Recap extends StatelessWidget {
  const _Recap({required this.state});

  final SeasonClosureState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    final plan = state.plan!;
    final season = plan.season;
    return SectionCard(
      title: l10n.closureRecapTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.closureRecapPeriod(
              dates.formatMediumDate(season.startDate),
              dates.formatMediumDate(season.endDate),
            ),
          ),
          Text(l10n.closureRecapLine(plan.sessionCount, plan.presenceCount)),
          Text(l10n.closureRecapStudents(plan.proposals.length)),
          if (plan.early) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.closureEarly(
                dates.formatMediumDate(season.endDate),
                dates.formatMediumDate(plan.closedOn),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.state});

  final SeasonClosureState state;

  String _reason(AppLocalizations l10n, ClosureReason reason) =>
      switch (reason) {
        ClosureReason.inactive => l10n.closureReasonInactive,
        ClosureReason.retentionExpired => l10n.closureReasonRetention,
        ClosureReason.carriedOver => l10n.closureReasonCarried,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<SeasonClosureBloc>();
    final proposals = state.plan!.proposals;
    return SectionCard(
      title: l10n.closureChoicesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (proposals.isEmpty)
            Text(l10n.closureNoStudents)
          else ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: () => bloc.add(
                    const SeasonClosureEvent.allSet(choice: ClosureChoice.keep),
                  ),
                  child: Text(l10n.closureKeepAll),
                ),
                OutlinedButton(
                  onPressed: () => bloc.add(
                    const SeasonClosureEvent.allSet(
                      choice: ClosureChoice.erase,
                    ),
                  ),
                  child: Text(l10n.closureEraseAll),
                ),
              ],
            ),
            for (final proposal in proposals)
              ClosureChoiceTile(
                key: ValueKey('closure-tile:${proposal.studentId.value}'),
                name: proposal.firstName,
                reason: _reason(l10n, proposal.reason),
                erase: state.choices[proposal.studentId] == ClosureChoice.erase,
                onChanged: (erase) => bloc.add(
                  SeasonClosureEvent.choiceSet(
                    studentId: proposal.studentId,
                    choice: erase ? ClosureChoice.erase : ClosureChoice.keep,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.state});

  final SeasonClosureState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<SeasonClosureBloc>();
    final planned = state.plan!.plannedToDrop;
    return SectionCard(
      title: l10n.closureOptionsTitle,
      child: Column(
        children: [
          CheckboxListTile(
            key: const ValueKey('closure-prepare-next'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: state.prepareNext,
            onChanged: (value) => bloc.add(
              SeasonClosureEvent.prepareNextSet(value: value ?? false),
            ),
            title: Text(l10n.closurePrepareNext),
          ),
          CheckboxListTile(
            key: const ValueKey('closure-drop-planned'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: planned > 0 && state.dropPlanned,
            onChanged: planned == 0
                ? null
                : (value) => bloc.add(
                    SeasonClosureEvent.dropPlannedSet(value: value ?? false),
                  ),
            title: Text(l10n.closureDropPlanned(planned)),
          ),
        ],
      ),
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.state});

  final SeasonClosureState state;

  Future<void> _close(BuildContext context) async {
    final bloc = context.read<SeasonClosureBloc>();
    if (state.erasedCount == 0) {
      bloc.add(const SeasonClosureEvent.confirmed());
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(count: state.erasedCount),
    );
    if (confirmed ?? false) bloc.add(const SeasonClosureEvent.confirmed());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final erased = state.erasedCount;
    final failure = state.failure;
    final working = state.status == SeasonClosureStatus.closing;
    return SectionCard(
      title: l10n.closureConfirmTitle,
      emphasis: SectionEmphasis.high,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.closureSummary(erased, state.keptCount),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const ValueKey('closure-close'),
            style: erased == 0
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
            onPressed: working ? null : () => _close(context),
            child: Text(
              erased == 0
                  ? l10n.closureActionClose
                  : l10n.closureActionEraseAndClose(erased),
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              failureMessage(l10n, failure),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dernière garde avant l'effacement : le nombre en toutes lettres et une case
/// « J'ai compris » qui débloque le bouton.
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.count});

  final int count;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.closureDialogTitle(widget.count)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.closureDialogBody),
            CheckboxListTile(
              key: const ValueKey('closure-understood'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: (value) => setState(() => _understood = value!),
              title: Text(l10n.closureUnderstood),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('closure-erase-and-close'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.closureActionEraseAndClose(widget.count)),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.state,
    required this.backupAfterSection,
    required this.onSeasons,
    required this.onHome,
  });

  final SeasonClosureState state;
  final Widget backupAfterSection;
  final VoidCallback onSeasons;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = state.result!;
    return SectionCard(
      title: l10n.closureDoneTitle,
      emphasis: SectionEmphasis.high,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.closureDoneSeason(state.plan!.season.label)),
          Text(l10n.closureDoneErased(result.erased)),
          Text(l10n.closureDoneKept(result.kept)),
          Text(l10n.closureDoneGroups(result.groupsPrepared)),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.closureDoneBackup),
          const SizedBox(height: AppSpacing.sm),
          backupAfterSection,
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                onPressed: onSeasons,
                child: Text(l10n.closureDoneSeasons),
              ),
              OutlinedButton(
                onPressed: onHome,
                child: Text(l10n.closureDoneHome),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
