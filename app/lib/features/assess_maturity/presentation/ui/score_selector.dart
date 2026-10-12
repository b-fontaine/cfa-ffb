import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Un critère noté de 1 à 4 : libellé et quatre choix de 48 dp. Le choix
/// courant est annoncé « critère : n sur 4 » (jamais la couleur seule).
class ScoreSelector extends StatelessWidget {
  const ScoreSelector({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;

  /// Note choisie ; `null` tant que l'animateur n'a pas choisi.
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = value;
    return Semantics(
      container: true,
      label: current == null
          ? label
          : l10n.assessScoreSemantics(label, current),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(label, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<int>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              for (
                var score = MaturityAssessment.minScore;
                score <= MaturityAssessment.maxScore;
                score++
              )
                ButtonSegment(value: score, label: Text('$score')),
            ],
            selected: {?current},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) onChanged(selection.first);
            },
          ),
        ],
      ),
    );
  }
}
