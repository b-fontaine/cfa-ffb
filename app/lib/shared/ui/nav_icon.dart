import 'package:flutter/material.dart';

/// Glyphes dédiés de la navigation principale (R3), dessinés sans police
/// d'icônes : table vue de dessus, deux billes, fiche à pastilles, maison,
/// losange du rail.
enum NavGlyph { sessions, students, results, today, more }

/// Icône de navigation de 24 dp (par défaut), peinte avec la couleur et la
/// taille de l'`IconTheme` courant : `NavigationBar` et `NavigationRail`
/// l'ajustent selon l'état. Sélectionné = plein, non sélectionné = contour ;
/// le libellé de la destination porte le sens, le glyphe est exclu de
/// l'arbre sémantique.
class NavIcon extends StatelessWidget {
  const NavIcon(this.glyph, {this.selected = false, super.key});

  final NavGlyph glyph;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: NavIconPainter(
          glyph: glyph,
          filled: selected,
          color: theme.color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Peintre d'un [NavGlyph] (public pour être testé), dans une grille de 24.
class NavIconPainter extends CustomPainter {
  const NavIconPainter({
    required this.glyph,
    required this.filled,
    required this.color,
  });

  final NavGlyph glyph;
  final bool filled;
  final Color color;

  static const double _grid = 24;
  static const double _stroke = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / _grid;
    canvas
      ..save()
      ..scale(unit)
      // Calque : les détails du glyphe plein sont « gravés » (transparents).
      ..saveLayer(const Rect.fromLTWH(0, 0, _grid, _grid), Paint());
    final body = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final solid = Paint()..color = color;
    final engrave = Paint()..blendMode = BlendMode.clear;
    switch (glyph) {
      case NavGlyph.sessions:
        _table(canvas, body, solid, engrave);
      case NavGlyph.students:
        _balls(canvas, body);
      case NavGlyph.results:
        _sheet(canvas, body, solid, engrave);
      case NavGlyph.today:
        _house(canvas, body, engrave);
      case NavGlyph.more:
        _diamond(canvas, body, engrave);
    }
    canvas
      ..restore()
      ..restore();
  }

  void _table(Canvas canvas, Paint body, Paint solid, Paint engrave) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2.5, 5.5, 19, 13),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(rect, body);
    const pockets = [
      Offset(6, 9),
      Offset(18, 9),
      Offset(6, 15),
      Offset(18, 15),
    ];
    for (final pocket in pockets) {
      canvas.drawCircle(pocket, 1.4, filled ? engrave : solid);
    }
  }

  void _balls(Canvas canvas, Paint body) {
    canvas
      ..drawCircle(const Offset(7.5, 15), 4.5, body)
      ..drawCircle(const Offset(16.5, 9), 4.5, body);
  }

  void _sheet(Canvas canvas, Paint body, Paint solid, Paint engrave) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4.5, 2.5, 15, 19),
      const Radius.circular(2.5),
    );
    final detail = filled ? engrave : solid
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(rect, body);
    for (final y in const [8.0, 12.0, 16.0]) {
      canvas
        ..drawCircle(Offset(9, y), 1.2, detail)
        ..drawLine(Offset(12.5, y), Offset(16, y), detail);
    }
  }

  void _house(Canvas canvas, Paint body, Paint engrave) {
    final path = Path()
      ..moveTo(12, 3)
      ..lineTo(21.5, 11.5)
      ..lineTo(19, 11.5)
      ..lineTo(19, 20.5)
      ..lineTo(5, 20.5)
      ..lineTo(5, 11.5)
      ..lineTo(2.5, 11.5)
      ..close();
    canvas.drawPath(path, body);
    if (filled) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(10, 14, 4, 6.5),
          const Radius.circular(1),
        ),
        engrave,
      );
    }
  }

  void _diamond(Canvas canvas, Paint body, Paint engrave) {
    final path = Path()
      ..moveTo(12, 2.5)
      ..lineTo(21.5, 12)
      ..lineTo(12, 21.5)
      ..lineTo(2.5, 12)
      ..close();
    canvas.drawPath(path, body);
    if (filled) {
      canvas.drawCircle(const Offset(12, 12), 2.2, engrave);
    }
  }

  @override
  bool shouldRepaint(NavIconPainter old) =>
      old.glyph != glyph || old.filled != filled || old.color != color;
}
