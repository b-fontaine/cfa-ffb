import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/domain/stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_cubit.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_state.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La carte « Marqueurs abandonnés » de « Mon club », branchée sur le
/// [StaleMarkersCubit] fourni par l'appelant.
class StaleMarkersSection extends StatelessWidget {
  const StaleMarkersSection({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<StaleMarkersCubit, StaleMarkersState>(
        builder: (context, state) => StaleMarkersCard(
          state: state,
          onPurge: () => context.read<StaleMarkersCubit>().purge(),
        ),
      );
}

/// « Marqueurs abandonnés » (FB8 partie B, B5) : ce qu'est un marqueur, le
/// délai de [staleMarkerAge], le **risque d'un nouvel import** une fois le
/// marqueur d'un import terminé effacé, le bouton, puis l'issue (nombre
/// supprimé, plafond du jour, échec et relance).
class StaleMarkersCard extends StatelessWidget {
  const StaleMarkersCard({
    required this.state,
    required this.onPurge,
    super.key,
  });

  final StaleMarkersState state;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final running = state is StaleMarkersRunning;
    return SectionCard(
      title: l10n.staleMarkersTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.staleMarkersBody(staleMarkerAge.inDays),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppAlert(
            level: AlertLevel.attention,
            message: l10n.staleMarkersWarning,
          ),
          const SizedBox(height: AppSpacing.md),
          if (running) ...[
            Semantics(
              liveRegion: true,
              label: l10n.staleMarkersRunning,
              child: const LinearProgressIndicator(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.staleMarkersRunning, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (state case StaleMarkersFinished(:final result)) ...[
            Semantics(liveRegion: true, child: _Outcome(result: result)),
            const SizedBox(height: AppSpacing.sm),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: running ? null : onPurge,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(l10n.staleMarkersAction),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'issue d'une purge, en toutes lettres.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.result});

  final StaleMarkerPurgeResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = result.failure;
    return switch (result.status) {
      StaleMarkerPurgeStatus.completed => Text(
        l10n.staleMarkersDone(result.removed),
      ),
      StaleMarkerPurgeStatus.paused => AppAlert(
        level: AlertLevel.attention,
        message: l10n.staleMarkersPaused(result.removed),
      ),
      StaleMarkerPurgeStatus.interrupted ||
      StaleMarkerPurgeStatus.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) ...[
            AppAlert(
              level: AlertLevel.persistent,
              message: failureMessage(l10n, failure),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(l10n.staleMarkersStopped(result.removed)),
        ],
      ),
    };
  }
}
