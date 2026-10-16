import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:flutter/material.dart';

/// Motif de tapis : une grille de losanges (8 colonnes sur 4 rangées) en bleu
/// tapis très atténué, posée derrière un en-tête. Purement décoratif : exclu
/// de la sémantique, sans dépendance ni image.
class ClothPattern extends StatelessWidget {
  const ClothPattern({super.key});

  /// Opacité des losanges : assez faible pour rester décoratif, le contraste
  /// du texte posé dessus est vérifié à cette valeur (test de contraste).
  static const double opacity = 0.06;

  @override
  Widget build(BuildContext context) {
    final balls = Theme.of(context).extension<BallColors>() ?? BallColors.light;
    return ExcludeSemantics(
      child: CustomPaint(
        painter: ClothPatternPainter(
          color: balls.cloth.withValues(alpha: opacity),
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Peintre du motif de tapis.
class ClothPatternPainter extends CustomPainter {
  const ClothPatternPainter({required this.color});

  static const columns = 8;
  static const rows = 4;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < rows; row++) {
        final center = Offset(
          (column + 0.5) * cellWidth,
          (row + 0.5) * cellHeight,
        );
        final half = cellHeight * 0.18;
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - half)
            ..lineTo(center.dx + half, center.dy)
            ..lineTo(center.dx, center.dy + half)
            ..lineTo(center.dx - half, center.dy)
            ..close(),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ClothPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
