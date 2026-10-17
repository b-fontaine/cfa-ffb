import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/timer_tone.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// Affiche [remaining] en `mm:ss`, ou `+mm:ss` au dépassement.
String formatTimer(Duration remaining) {
  final total = remaining.abs().inSeconds;
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '${remaining.isNegative ? '+' : ''}$minutes:$seconds';
}

/// Minuteur compact : temps restant en `titleLarge`, fond neutre puis
/// `StatusColors.attention` sous une minute puis `inverseSurface` (sombre,
/// jamais le rouge d'état : ADR 0010) au dépassement, avec une icône
/// sablier et le temps en `+mm:ss` (jamais la couleur seule), et un bouton
/// unique lecture / pause (cible ≥ 48 dp).
///
/// Sans minuterie interne : l'appelant fournit [remaining], [running] et
/// [onToggle] (testable sans horloge). Le lecteur d'écran n'annonce que les
/// changements de ton (une seule région vive, au seuil), pas chaque seconde.
class TimerChip extends StatelessWidget {
  const TimerChip({
    required this.remaining,
    required this.running,
    required this.onToggle,
    super.key,
  });

  final Duration remaining;
  final bool running;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = theme.extension<StatusColors>() ?? StatusColors.light;
    final tone = timerToneFor(remaining);
    final (background, foreground) = switch (tone) {
      TimerTone.neutral => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
      ),
      TimerTone.attention => (status.attention, status.onAttention),
      TimerTone.overdue => (
        theme.colorScheme.inverseSurface,
        theme.colorScheme.onInverseSurface,
      ),
    };
    final time = formatTimer(remaining);
    final label = tone == TimerTone.overdue
        ? l10n.timerOverdue(formatTimer(remaining.abs()))
        : l10n.timerRemaining(time);
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        key: const ValueKey('timer-chip'),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadii.mediumRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tone != TimerTone.neutral) ...[
                Semantics(
                  key: const ValueKey('timer-chip-live'),
                  container: true,
                  liveRegion: true,
                  label: tone == TimerTone.overdue
                      ? l10n.timerLiveOverdue
                      : l10n.timerLiveAttention,
                  excludeSemantics: true,
                  child: Icon(
                    tone == TimerTone.overdue
                        ? Icons.hourglass_bottom
                        : Icons.warning_amber_rounded,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      time,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foreground,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size.square(AppSpacing.minTouchTarget),
                ),
                tooltip: running ? l10n.timerPause : l10n.timerStart,
                onPressed: onToggle,
                icon: Icon(running ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
