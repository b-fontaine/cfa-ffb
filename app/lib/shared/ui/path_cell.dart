import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// État d'une case du parcours d'un élève : la forme et le texte portent le
/// sens, la couleur l'appuie seulement.
///
/// - [todo] : contour vide ;
/// - [started] : hachuré, avec le nombre de passages réussis ;
/// - [validated] : plein, avec une coche ;
/// - [acquired] : plein clair, avec un drapeau (acquis au positionnement,
///   ADR 0008), distinct de [validated].
enum PathCellState { todo, started, validated, acquired }

const double _cellGlyph = 36;
const double _legendGlyph = 24;

/// Une case du parcours (une par exercice), de 48 × 48 dp au moins.
///
/// [label] est le nom accessible complet (« exercice : état, … ») : la case
/// n'est jamais lue par sa couleur. Sans [onTap], la case est un simple
/// repère (vue « à montrer à l'élève »). [alerted] ajoute une icône
/// d'attention (jamais rouge, ADR 0010) et [current] un anneau qui désigne
/// l'exercice en cours.
class PathCell extends StatelessWidget {
  const PathCell({
    required this.state,
    required this.label,
    this.passed = 0,
    this.alerted = false,
    this.current = false,
    this.onTap,
    super.key,
  });

  final PathCellState state;
  final String label;

  /// Passages réussis, écrits dans une case [PathCellState.started].
  final int passed;
  final bool alerted;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = SizedBox.square(
      dimension: AppSpacing.minTouchTarget,
      child: Center(
        child: _PathGlyph(
          state: state,
          size: _cellGlyph,
          passed: passed,
          alerted: alerted,
          current: current,
        ),
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null
          ? body
          : InkResponse(
              onTap: onTap,
              radius: AppSpacing.minTouchTarget / 2,
              child: body,
            ),
    );
  }
}

/// Légende du parcours : les quatre états en toutes lettres, avec leur forme,
/// et le nombre d'exercices du catalogue.
class PathLegend extends StatelessWidget {
  const PathLegend({required this.exerciseCount, super.key});

  final int exerciseCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labels = {
      PathCellState.todo: l10n.pathLegendTodo,
      PathCellState.started: l10n.pathLegendStarted,
      PathCellState.validated: l10n.pathLegendValidated,
      PathCellState.acquired: l10n.pathLegendAcquired,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final entry in labels.entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: _PathGlyph(
                      state: entry.key,
                      size: _legendGlyph,
                      passed: 0,
                      alerted: false,
                      current: false,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(entry.value, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.pathLegendTotal(exerciseCount),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PathGlyph extends StatelessWidget {
  const _PathGlyph({
    required this.state,
    required this.size,
    required this.passed,
    required this.alerted,
    required this.current,
  });

  final PathCellState state;
  final double size;
  final int passed;
  final bool alerted;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = theme.extension<StatusColors>() ?? StatusColors.light;
    final radius = BorderRadius.circular(size / 4);
    final (fill, border, content) = switch (state) {
      PathCellState.todo => (
        Colors.transparent,
        scheme.outline,
        const SizedBox.shrink(),
      ),
      PathCellState.started => (
        scheme.surface,
        scheme.secondary,
        ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: _HatchPainter(scheme.secondaryContainer),
            child: Center(
              child: passed > 0
                  ? Text(
                      '$passed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
      PathCellState.validated => (
        scheme.secondary,
        scheme.secondary,
        Icon(Icons.check, size: size * 0.6, color: scheme.onSecondary),
      ),
      PathCellState.acquired => (
        scheme.secondaryContainer,
        scheme.secondary,
        Icon(
          Icons.bookmark_added,
          size: size * 0.55,
          color: scheme.onSecondaryContainer,
        ),
      ),
    };
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (current)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: DecoratedBox(
                key: const ValueKey('path-marker-current'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size / 4 + 3),
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              key: ValueKey('path-glyph-${state.name}'),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: radius,
                border: Border.all(color: border, width: 2),
              ),
              child: Center(child: content),
            ),
          ),
          if (alerted)
            Positioned(
              top: -4,
              right: -4,
              child: DecoratedBox(
                key: const ValueKey('path-marker-alert'),
                decoration: BoxDecoration(
                  color: status.attention,
                  shape: BoxShape.circle,
                  border: Border.all(color: status.onAttention),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Icon(
                    Icons.priority_high,
                    size: 12,
                    color: status.onAttention,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hachures diagonales : le fond d'une case commencée.
class _HatchPainter extends CustomPainter {
  const _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3;
    const step = 7.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.color != color;
}
