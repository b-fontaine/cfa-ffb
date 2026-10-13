import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Bande des quantités de bille : une rangée de [BallContactDiagram], l'une
/// pouvant être mise en évidence.
///
/// La mise en évidence ne tient pas à la couleur seule : cadre épais et coche,
/// et la quantité est nommée dans la description parlée. Les schémas passent à
/// la ligne quand la place manque.
class ContactStrip extends StatelessWidget {
  const ContactStrip({required this.fractions, this.highlight, super.key});

  /// Quantités à montrer, dans l'ordre.
  final List<ContactFraction> fractions;

  /// Quantité mise en évidence ; sans effet si elle n'est pas dans
  /// [fractions].
  final ContactFraction? highlight;

  /// Largeur minimale d'un schéma avant de passer à la ligne.
  static const double _minItemWidth = 96;

  /// Largeur d'un schéma quand la place n'est pas bornée.
  static const double _unboundedItemWidth = 160;

  @override
  Widget build(BuildContext context) {
    if (fractions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final names = fractions
        .map((f) => BallContactDiagram.contactLabel(l10n, f))
        .join(', ');
    final marked = highlight != null && fractions.contains(highlight)
        ? highlight
        : null;
    final label = marked == null
        ? l10n.contactStripLabel(names)
        : l10n.contactStripHighlightedLabel(
            names,
            BallContactDiagram.contactLabel(l10n, marked),
          );
    return Semantics(
      label: label,
      container: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppSpacing.sm;
          final bounded = constraints.maxWidth.isFinite;
          final columns = bounded
              ? math.max(
                  1,
                  math.min(
                    fractions.length,
                    ((constraints.maxWidth + gap) / (_minItemWidth + gap))
                        .floor(),
                  ),
                )
              : fractions.length;
          final itemWidth = bounded
              ? (constraints.maxWidth - (columns - 1) * gap) / columns
              : _unboundedItemWidth;
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final fraction in fractions)
                SizedBox(
                  width: itemWidth,
                  child: _StripItem(
                    fraction: fraction,
                    highlighted: fraction == marked,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({required this.fraction, required this.highlighted});

  final ContactFraction fraction;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diagram = Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: BallContactDiagram(contact: fraction),
    );
    if (!highlighted) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(width: 3, color: Colors.transparent),
          borderRadius: AppRadii.smallRadius,
        ),
        child: diagram,
      );
    }
    return DecoratedBox(
      key: const ValueKey('contact-strip-highlight'),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        border: Border.all(width: 3, color: scheme.primary),
        borderRadius: AppRadii.smallRadius,
      ),
      child: Stack(
        children: [
          diagram,
          Positioned(
            top: 0,
            right: 0,
            child: ExcludeSemantics(
              child: Icon(Icons.check_circle, size: 18, color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
