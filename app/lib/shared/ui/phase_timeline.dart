import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Une phase de la frise : libellé et durée en minutes (données du
/// parent ; `shared/ui` ne connaît pas le domaine).
@immutable
class PhaseTimelineEntry {
  const PhaseTimelineEntry({required this.label, required this.minutes})
    : assert(minutes > 0, 'minutes must be positive');

  final String label;
  final int minutes;
}

/// Frise des phases d'une séance : un segment par phase, de largeur
/// proportionnelle à sa durée mais jamais sous la cible tactile minimale
/// (48 dp) ; les phases courtes sont relevées à 48 dp et le surplus est
/// reparti entre les autres au prorata des minutes.
///
/// La phase courante ([currentIndex], à partir de 0) se distingue par un
/// remplissage `secondaryContainer`, un contour épais et un libellé gras :
/// jamais par la couleur seule. Taper un segment appelle [onSelected] avec
/// son index. Un libellé long est tronqué à l'écran mais reste entier dans la
/// sémantique (« Phase 2 sur 5 : entraînement, 35 min, en cours ») et dans
/// l'infobulle. Si les segments minimaux ne tiennent pas dans la largeur, la
/// frise défile horizontalement.
class PhaseTimeline extends StatelessWidget {
  const PhaseTimeline({
    required this.phases,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  }) : assert(phases.length > 0, 'phases must not be empty');

  final List<PhaseTimelineEntry> phases;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const double _height = 56;
  static const double _gap = 2;
  static const double _minWidth = AppSpacing.minTouchTarget;
  static const double _minutesUnitWidth = 72;

  /// Largeurs proportionnelles aux minutes, relevées à [_minWidth].
  static List<double> widthsFor(List<int> minutes, double available) {
    final count = minutes.length;
    final usable = available - (count - 1) * _gap;
    final widths = List<double>.filled(count, _minWidth);
    if (usable <= count * _minWidth) return widths;
    final clamped = <int>{};
    while (true) {
      final free = usable - clamped.length * _minWidth;
      final freeMinutes = [
        for (var i = 0; i < count; i++)
          if (!clamped.contains(i)) minutes[i],
      ].fold<int>(0, (sum, value) => sum + value);
      final tooShort = [
        for (var i = 0; i < count; i++)
          if (!clamped.contains(i) &&
              free * minutes[i] / freeMinutes < _minWidth)
            i,
      ];
      if (tooShort.isEmpty) {
        for (var i = 0; i < count; i++) {
          if (!clamped.contains(i)) widths[i] = free * minutes[i] / freeMinutes;
        }
        return widths;
      }
      clamped.addAll(tooShort);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = phases.fold<int>(0, (sum, phase) => sum + phase.minutes);
    return Semantics(
      container: true,
      label: l10n.phaseTimelineLabel(total),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widths = widthsFor([
            for (final phase in phases) phase.minutes,
          ], constraints.maxWidth);
          final needed =
              widths.fold<double>(0, (sum, w) => sum + w) +
              (phases.length - 1) * _gap;
          final row = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < phases.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                _Segment(
                  key: ValueKey('phase-${i + 1}'),
                  entry: phases[i],
                  index: i,
                  count: phases.length,
                  width: widths[i],
                  current: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
              ],
            ],
          );
          if (needed > constraints.maxWidth) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            );
          }
          return row;
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.entry,
    required this.index,
    required this.count,
    required this.width,
    required this.current,
    required this.onTap,
    super.key,
  });

  final PhaseTimelineEntry entry;
  final int index;
  final int count;
  final double width;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = current
        ? l10n.phaseTimelinePhaseCurrent(
            index + 1,
            count,
            entry.label,
            entry.minutes,
          )
        : l10n.phaseTimelinePhase(index + 1, count, entry.label, entry.minutes);
    final foreground = current ? scheme.onSecondaryContainer : scheme.onSurface;
    final minutes = width >= PhaseTimeline._minutesUnitWidth
        ? l10n.sessionDurationMinutes(entry.minutes)
        : '${entry.minutes}';
    // La hauteur suit l'échelle du texte : à 200 %, les deux lignes du segment
    // (minutes et libellé) y tiennent sans débordement.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      width: width,
      height: PhaseTimeline._height * math.max(1, textScale),
      child: Semantics(
        button: true,
        selected: current,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message:
              '${entry.label} · ${l10n.sessionDurationMinutes(entry.minutes)}',
          child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: BoxDecoration(
                color: current
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: AppRadii.smallRadius,
                border: Border.all(
                  color: current ? scheme.secondary : scheme.outlineVariant,
                  width: current ? 3 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: AppRadii.smallRadius,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        minutes,
                        maxLines: 1,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: current
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
