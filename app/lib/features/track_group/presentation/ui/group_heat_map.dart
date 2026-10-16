import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/cell_grid.dart';
import 'package:billard_cfa/shared/ui/heat_cell.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// La carte de chaleur d'un groupe : une ligne par technique, une colonne par
/// élève, une dernière ligne d'assiduité.
///
/// Chaque cellule écrit sa fraction d'exercices validés (« 3/4 »), porte un
/// nom accessible complet (élève, technique, fraction, état, alerte) et doublé
/// la teinte d'une coche, d'un drapeau ou d'un avertissement : la couleur ne
/// porte jamais seule le sens. Chaque ligne est aussi résumée en toutes
/// lettres. Toucher une cellule ou un prénom ouvre la fiche de l'élève
/// ([onOpenStudent]) ; la grille ne permet aucune écriture.
class GroupHeatMap extends StatelessWidget {
  const GroupHeatMap({
    required this.grid,
    required this.onOpenStudent,
    super.key,
  });

  final GroupGrid grid;
  final ValueChanged<StudentId> onOpenStudent;

  static HeatLevel _level(GridCell cell) => switch (cell.tier) {
    HeatTier.none => HeatLevel.none,
    HeatTier.some => HeatLevel.some,
    HeatTier.most => HeatLevel.most,
    HeatTier.all => HeatLevel.all,
  };

  static String _status(AppLocalizations l10n, BlockStatus status) =>
      switch (status) {
        BlockStatus.notStarted => l10n.statusNotStarted,
        BlockStatus.inProgress => l10n.statusInProgress,
        BlockStatus.toReview => l10n.statusToReview,
        BlockStatus.mastered => l10n.statusMastered,
        BlockStatus.acquiredAtPlacement => l10n.statusAcquiredAtPlacement,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (grid.students.isEmpty) {
      return Text(l10n.groupGridNoMember, style: theme.textTheme.bodyLarge);
    }
    final names = {for (final s in grid.students) s.id: s.firstName};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CellGrid(
          keyPrefix: 'heat',
          semanticLabel: l10n.groupSubtitle,
          columns: [
            for (final student in grid.students)
              CellGridColumn(
                id: student.id.value,
                label: student.firstName,
                semanticLabel: l10n.studentsOpenSheet(student.firstName),
                onTap: () => onOpenStudent(student.id),
              ),
          ],
          rows: [
            for (final row in grid.rows)
              CellGridRow(
                id: row.technique.blockId,
                header: row.technique.title,
                semanticLabel: l10n.groupGridRow(
                  row.technique.title,
                  row.finished.length,
                  row.cells.length,
                  row.inProgress.length,
                  row.toStart.length,
                ),
                cells: [
                  for (final cell in row.cells)
                    HeatCell(
                      key: ValueKey(
                        'heat-cell-${row.technique.blockId}-'
                        '${cell.studentId.value}',
                      ),
                      fraction: l10n.groupGridFraction(
                        cell.doneCount,
                        cell.total,
                      ),
                      level: _level(cell),
                      acquired: cell.status == BlockStatus.acquiredAtPlacement,
                      alerted: cell.alerted,
                      label: [
                        l10n.groupGridCell(
                          names[cell.studentId] ?? cell.studentId.value,
                          row.technique.title,
                          cell.doneCount,
                          cell.total,
                          _status(l10n, cell.status),
                        ),
                        if (cell.alerted) l10n.pathCellAlerted,
                      ].join(', '),
                      onTap: () => onOpenStudent(cell.studentId),
                    ),
                ],
              ),
          ],
          footer: CellGridRow(
            id: 'attendance',
            header: l10n.sheetAttendanceTitle,
            semanticLabel: l10n.sheetAttendanceTitle,
            cells: [
              for (final student in grid.students)
                _Attendance(
                  name: student.firstName,
                  attended: student.attendance.attended,
                  total: student.attendance.total,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.groupGridLegend, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Attendance extends StatelessWidget {
  const _Attendance({
    required this.name,
    required this.attended,
    required this.total,
  });

  final String name;
  final int attended;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final empty = total == 0;
    return Semantics(
      container: true,
      label: l10n.groupGridAttendanceCell(
        name,
        empty
            ? l10n.sheetAttendanceNone
            : l10n.sheetAttendance(attended, total),
      ),
      excludeSemantics: true,
      child: Text(
        empty
            ? l10n.groupGridNoSession
            : l10n.groupGridFraction(attended, total),
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}
