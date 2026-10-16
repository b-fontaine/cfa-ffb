import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Marqueur de parcours d'une séance pour le groupe choisi : coche (faite),
/// lecture (recommandée ensuite) ou cercle vide (à venir).
///
/// Le sens est porté par la forme de l'icône ET par l'étiquette sémantique,
/// jamais par la couleur seule ; le bleu-tapis (`secondary`) appuie les états
/// faits ou recommandés, jamais le rouge (ADR 0010). Cible de 48 dp.
class JourneyMarker extends StatelessWidget {
  const JourneyMarker({required this.mark, super.key});

  final JourneyMark mark;

  /// L'étiquette lue par les lecteurs d'écran, aussi affichée en légende.
  static String labelOf(AppLocalizations l10n, JourneyMark mark) =>
      switch (mark) {
        JourneyMark.done => l10n.journeyDone,
        JourneyMark.next => l10n.journeyNext,
        JourneyMark.upcoming => l10n.journeyUpcoming,
      };

  /// L'icône du marqueur (aussi utilisée par la légende).
  static IconData iconOf(JourneyMark mark) => switch (mark) {
    JourneyMark.done => Icons.check_circle,
    JourneyMark.next => Icons.play_circle,
    JourneyMark.upcoming => Icons.radio_button_unchecked,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = mark == JourneyMark.upcoming
        ? scheme.onSurfaceVariant
        : scheme.secondary;
    return Semantics(
      label: labelOf(AppLocalizations.of(context), mark),
      excludeSemantics: true,
      child: SizedBox(
        width: AppSpacing.minTouchTarget,
        height: AppSpacing.minTouchTarget,
        child: Center(child: Icon(iconOf(mark), color: color, size: 28)),
      ),
    );
  }
}
