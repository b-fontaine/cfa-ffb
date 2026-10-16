import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Une ligne du tableau d'archive : un exercice et ses cumuls (jamais un
/// nom d'élève).
typedef ArchiveFigureRow = ({
  String title,
  int number,
  int students,
  int attempts,
  int potted,
  int total,
});

/// Tableau des exercices d'une saison close : exercice, élèves, passages,
/// billes. Chaque ligne se lit d'un bloc au lecteur d'écran (« Posture,
/// exercice 1 : 3 élèves, 6 passages, 9 billes sur 18 »).
class ArchiveFigureTable extends StatelessWidget {
  const ArchiveFigureTable({required this.rows, super.key});

  final List<ArchiveFigureRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final header = theme.textTheme.labelLarge;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(1.4),
      },
      children: [
        TableRow(
          children: [
            _cell(Text(l10n.archiveColExercise, style: header)),
            _cell(Text(l10n.archiveColStudents, style: header)),
            _cell(Text(l10n.archiveColAttempts, style: header)),
            _cell(Text(l10n.archiveColBalls, style: header)),
          ],
        ),
        for (final row in rows)
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            children: [
              _cell(
                Semantics(
                  label: l10n.archiveRowLabel(
                    row.title,
                    row.number,
                    row.students,
                    row.attempts,
                    row.potted,
                    row.total,
                  ),
                  excludeSemantics: true,
                  child: Text(
                    l10n.archiveExerciseLabel(row.title, row.number),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              _cell(ExcludeSemantics(child: Text('${row.students}'))),
              _cell(ExcludeSemantics(child: Text('${row.attempts}'))),
              _cell(
                ExcludeSemantics(
                  child: Text(l10n.archiveBalls(row.potted, row.total)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.sm,
      horizontal: AppSpacing.xs,
    ),
    child: child,
  );
}
