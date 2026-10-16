import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Colonne d'une [CellGrid] : un élève, un jour… Une cible de 48 dp au moins
/// quand [onTap] est donné.
class CellGridColumn {
  const CellGridColumn({
    required this.id,
    required this.label,
    this.semanticLabel,
    this.onTap,
  });

  final String id;
  final String label;

  /// Nom accessible de l'en-tête (le [label] sinon).
  final String? semanticLabel;
  final VoidCallback? onTap;
}

/// Ligne d'une [CellGrid] : l'en-tête (la technique), son résumé lu en toutes
/// lettres et ses [cells], une par colonne et dans le même ordre.
class CellGridRow {
  const CellGridRow({
    required this.id,
    required this.header,
    required this.semanticLabel,
    required this.cells,
  });

  final String id;
  final String header;

  /// Résumé de la ligne, lu à la place de l'en-tête.
  final String semanticLabel;
  final List<Widget> cells;
}

/// Tableau à colonne d'en-têtes fixe : les lignes (techniques) restent à
/// gauche et les colonnes (élèves) défilent à l'horizontale, ce qui tient sur
/// un smartphone. Chaque cellule porte elle-même son nom accessible complet
/// (ligne et colonne) : le tableau se lit sans la vue.
///
/// Les clés sont `<keyPrefix>-row-<id>` (ligne), `<keyPrefix>-technique-<id>`
/// (en-tête de ligne), `<keyPrefix>-column-<id>` (en-tête de colonne) et
/// `<keyPrefix>-scroll` (zone qui défile). [footer] est une dernière ligne,
/// séparée (l'assiduité, par exemple).
class CellGrid extends StatelessWidget {
  const CellGrid({
    required this.keyPrefix,
    required this.semanticLabel,
    required this.columns,
    required this.rows,
    this.footer,
    this.headerWidth = 120,
    this.columnWidth = 64,
    super.key,
  });

  final String keyPrefix;
  final String semanticLabel;
  final List<CellGridColumn> columns;
  final List<CellGridRow> rows;
  final CellGridRow? footer;
  final double headerWidth;
  final double columnWidth;

  static const double _headerHeight = 56;
  static const double _minRowHeight = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    // Trois lignes de titre au plus, à la taille de texte de l'utilisateur.
    final rowHeight = math.max(
      _minRowHeight,
      scaler.scale((labelStyle.fontSize ?? 12) * (labelStyle.height ?? 1.4)) *
              3 +
          AppSpacing.md,
    );
    final all = [...rows, ?footer];
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: headerWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: _headerHeight),
                for (final row in all)
                  SizedBox(
                    height: rowHeight,
                    child: Semantics(
                      key: ValueKey('$keyPrefix-technique-${row.id}'),
                      container: true,
                      label: row.semanticLabel,
                      excludeSemantics: true,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: AppSpacing.sm,
                          ),
                          child: Text(
                            row.header,
                            style: labelStyle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('$keyPrefix-scroll'),
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final column in columns)
                        _ColumnHeader(
                          key: ValueKey('$keyPrefix-column-${column.id}'),
                          column: column,
                          width: columnWidth,
                          height: _headerHeight,
                        ),
                    ],
                  ),
                  for (final row in all)
                    SizedBox(
                      key: row == footer
                          ? null
                          : ValueKey('$keyPrefix-row-${row.id}'),
                      height: rowHeight,
                      child: Row(
                        children: [
                          for (final cell in row.cells)
                            SizedBox(
                              width: columnWidth,
                              child: Center(child: cell),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.column,
    required this.width,
    required this.height,
    super.key,
  });

  final CellGridColumn column;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Center(
      child: Text(
        column.label,
        style: theme.textTheme.labelMedium,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
    return Semantics(
      container: true,
      button: column.onTap != null,
      label: column.semanticLabel ?? column.label,
      excludeSemantics: true,
      onTap: column.onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: column.onTap == null
            ? text
            : InkWell(
                onTap: column.onTap,
                borderRadius: AppRadii.smallRadius,
                child: text,
              ),
      ),
    );
  }
}
