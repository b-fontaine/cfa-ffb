import 'package:billard_cfa/features/sync_status/domain/sync_state.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// Pastille discrète de synchronisation : « À jour », « Envoi en attente
/// (n) », « Hors ligne », ou le message d'un envoi refusé avec son action.
///
/// Couleurs de rôle (ADR 0010) : les états normaux (à jour, en attente, hors
/// ligne) sont bleu-tapis et neutres, **jamais rouges** ; seul un envoi refusé
/// prend la couleur d'attention. Le sens ne repose jamais sur la couleur seule
/// (icône et texte) ; la région est **vive** : un changement est annoncé aux
/// lecteurs d'écran. Aucun texte de donnée personnelle.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    required this.state,
    required this.onAcknowledgeFailure,
    super.key,
  });

  final SyncState state;

  /// « Compris » : l'animateur a lu le message d'un envoi refusé.
  final VoidCallback onAcknowledgeFailure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = theme.extension<StatusColors>() ?? StatusColors.light;
    final (background, foreground, icon, text) = switch (state.phase) {
      SyncPhase.upToDate => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
        Icons.cloud_done_outlined,
        l10n.syncUpToDate,
      ),
      SyncPhase.offline => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        Icons.cloud_off_outlined,
        l10n.syncOffline,
      ),
      SyncPhase.pending => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        state.offline ? Icons.cloud_off_outlined : Icons.cloud_upload_outlined,
        state.offline
            ? l10n.syncOfflinePending(state.pending)
            : l10n.syncPending(state.pending),
      ),
      SyncPhase.failed => (
        status.attention,
        status.onAttention,
        Icons.sync_problem_outlined,
        l10n.syncFailureMessage,
      ),
    };
    final failed = state.phase == SyncPhase.failed;
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.syncStatusLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadii.mediumRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 18, color: foreground)),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  text,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
              if (failed) ...[
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  onPressed: onAcknowledgeFailure,
                  child: Text(l10n.syncFailureAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
