import 'dart:math' as math;
import 'dart:math' show Point, Rectangle;

import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart' as geometry;

// Schéma de table imprimé (ADR 0021) : dessiné directement à partir de
// `DiagramTable`, en vectoriel et en niveaux de gris. Rien n'est porté par la
// couleur seule : chaque bille a sa lettre, les flèches se distinguent par
// leur trait (plein : bille touchée, tirets : blanche, points : indication),
// comme à l'écran. La géométrie (cases, rayons réels, ligne de départ) vient de
// `BlackballDimensions`, comme le dessin d'écran.

/// Le dessin d'un schéma : ses éléments, et la hauteur qu'il occupe.
class DiagramDrawing {
  const DiagramDrawing({required this.items, required this.height});

  final List<PrintItem> items;
  final double height;
}

const _labelSize = 6.5;
const _letterMinSize = 5.5;
const _dashCue = [4.0, 3.0];
const _dashIndication = [1.0, 3.0];
const _dashGhost = [2.0, 1.5];
const _dashZone = [3.0, 2.0];
const _dashObstacle = [1.5, 1.5];
const _margin = 1.0;

/// Dessine [table] dans la boîte de largeur [width] dont le coin haut gauche
/// est ([x], [y]) ; la hauteur est la moitié de la largeur (8 cases sur 4).
DiagramDrawing drawDiagram(
  DiagramTable table, {
  required double x,
  required double y,
  required double width,
  required TextMeasure measure,
}) {
  final cell = width / BlackballDimensions.columns;
  final height = cell * BlackballDimensions.rows;
  Point<double> at(Point<double> p) => Point(x + p.x * cell, y + p.y * cell);
  final box = Rectangle<double>(x, y, width, height);
  final items = <PrintItem>[
    PrintRect(
      x: x,
      y: y,
      width: width,
      height: height,
      fill: PrintShade.white,
      stroke: PrintShade.black,
      strokeWidth: 1.5,
      tag: 'table',
    ),
    PrintLine(
      from: Point(x + BlackballDimensions.headString * cell, y),
      to: Point(x + BlackballDimensions.headString * cell, y + height),
      shade: PrintShade.lightGray,
      dash: _dashGhost,
      tag: 'head-string',
    ),
  ];
  final occupied = <Rectangle<double>>[];
  final pocketRadius = BlackballDimensions.pocketOpening / 2 * cell;
  for (final pocket in geometry.TablePocket.values) {
    final center = at(pocket.point);
    items.add(
      PrintCircle(
        center: center,
        radius: pocketRadius,
        fill: PrintShade.darkGray,
        tag: 'pocket',
      ),
    );
    occupied.add(_square(center, pocketRadius));
  }

  for (final zone in table.zones) {
    final a = at(zone.from);
    final b = at(zone.to);
    items.add(
      PrintRect(
        x: math.min(a.x, b.x),
        y: math.min(a.y, b.y),
        width: (a.x - b.x).abs(),
        height: (a.y - b.y).abs(),
        stroke: PrintShade.darkGray,
        strokeWidth: 0.8,
        dash: _dashZone,
        tag: 'zone',
      ),
    );
  }

  final labels = <_Label>[];
  for (final ghost in table.ghosts) {
    final center = at(ghost.at);
    final radius = BlackballDimensions.cueBallRadius * cell;
    items.add(
      PrintCircle(
        center: center,
        radius: radius,
        stroke: PrintShade.black,
        strokeWidth: 0.8,
        dash: _dashGhost,
        tag: 'ghost',
      ),
    );
    occupied.add(_square(center, radius));
    final text = ghost.label;
    if (text != null && text.isNotEmpty) {
      labels.add(_Label(text, center, radius, _Side.right));
    }
  }
  for (final arrow in table.arrows) {
    final path = [for (final p in arrow.path) at(p)];
    if (path.length < 2) continue;
    items
      ..add(
        PrintPolyline(
          points: path,
          width: 1,
          dash: switch (arrow.kind) {
            TableArrowKind.object => const [],
            TableArrowKind.cue => _dashCue,
            TableArrowKind.indication => _dashIndication,
          },
          tag: 'arrow',
        ),
      )
      ..add(_arrowHead(path, cell));
    final text = arrow.label;
    if (text != null && text.isNotEmpty) {
      labels.add(_Label(text, _midpoint(path), 1, _Side.above));
    }
  }
  for (final ball in table.balls) {
    final center = at(ball.at);
    final isCue = ball.role == TableBallRole.cue;
    final radius =
        (isCue
            ? BlackballDimensions.cueBallRadius
            : BlackballDimensions.objectBallRadius) *
        cell;
    items
      ..add(
        PrintCircle(
          center: center,
          radius: radius,
          fill: switch (ball.color) {
            TableBallColor.black => PrintShade.black,
            TableBallColor.red => PrintShade.lightGray,
            TableBallColor.yellow || TableBallColor.white => PrintShade.white,
          },
          stroke: PrintShade.black,
          strokeWidth: 0.8,
          dash: ball.role == TableBallRole.obstacle ? _dashObstacle : const [],
          tag: 'ball',
        ),
      )
      ..add(
        PrintText(
          x: center.x,
          y: center.y + math.max(_letterMinSize, radius * 1.3) * 0.35,
          text: _letter(ball.color),
          size: math.max(_letterMinSize, radius * 1.3),
          style: PrintFontStyle.bold,
          shade: ball.color == TableBallColor.black
              ? PrintShade.white
              : PrintShade.black,
          align: PrintAlign.center,
          tag: 'ball-letter',
        ),
      );
    occupied.add(_square(center, radius));
    final order = ball.order;
    if (order != null) {
      items.add(
        PrintText(
          x: center.x - radius - 1,
          y: center.y - radius,
          text: '$order',
          size: _labelSize,
          style: PrintFontStyle.bold,
          align: PrintAlign.right,
          tag: 'ball-order',
        ),
      );
    }
    final text = ball.label;
    if (text != null && text.isNotEmpty) {
      labels.add(_Label(text, center, radius, _Side.right));
    }
  }
  for (final zone in table.zones) {
    final text = zone.label;
    if (text != null && text.isNotEmpty) {
      final corner = at(
        Point(
          math.min(zone.from.x, zone.to.x),
          math.min(zone.from.y, zone.to.y),
        ),
      );
      labels.add(_Label(text, corner, 0, _Side.belowRight));
    }
  }

  for (final label in labels) {
    final width = measure.width(label.text, _labelSize, PrintFontStyle.regular);
    final place = _place(label, width, box, occupied);
    occupied.add(Rectangle<double>(place.left, place.top, width, _labelSize));
    items.add(
      PrintText(
        x: place.left,
        y: place.top + _labelSize * 0.8,
        text: label.text,
        size: _labelSize,
        tag: 'label',
      ),
    );
  }
  return DiagramDrawing(items: items, height: height);
}

String _letter(TableBallColor color) => switch (color) {
  TableBallColor.red => 'R',
  TableBallColor.yellow => 'J',
  TableBallColor.black => 'N',
  TableBallColor.white => 'B',
};

/// Le carré de demi-côté [reach] centré sur [center] : l'emprise d'une bille,
/// d'une poche ou d'un cercle, pour éviter les chevauchements d'étiquettes.
Rectangle<double> _square(Point<double> center, double reach) =>
    Rectangle<double>(center.x - reach, center.y - reach, reach * 2, reach * 2);

/// Milieu d'une ligne brisée, par la longueur parcourue.
Point<double> _midpoint(List<Point<double>> path) {
  var total = 0.0;
  for (var i = 1; i < path.length; i++) {
    total += path[i - 1].distanceTo(path[i]);
  }
  var remaining = total / 2;
  for (var i = 1; i < path.length; i++) {
    final length = path[i - 1].distanceTo(path[i]);
    if (remaining <= length && length > 0) {
      final t = remaining / length;
      return Point(
        path[i - 1].x + (path[i].x - path[i - 1].x) * t,
        path[i - 1].y + (path[i].y - path[i - 1].y) * t,
      );
    }
    remaining -= length;
  }
  return path.last;
}

/// Pointe de flèche au bout de [path] (au moins deux points), orientée selon
/// le dernier segment non nul.
PrintPolygon _arrowHead(List<Point<double>> path, double cell) {
  final tip = path.last;
  var from = path[path.length - 2];
  for (var i = path.length - 2; i >= 0; i--) {
    from = path[i];
    if (from.distanceTo(tip) > 1e-9) break;
  }
  final length = math.max(5, cell * 0.12);
  final distance = from.distanceTo(tip);
  final ux = distance == 0 ? 1.0 : (tip.x - from.x) / distance;
  final uy = distance == 0 ? 0.0 : (tip.y - from.y) / distance;
  final baseX = tip.x - ux * length;
  final baseY = tip.y - uy * length;
  final half = length * 0.45;
  return PrintPolygon(
    points: [
      tip,
      Point(baseX - uy * half, baseY + ux * half),
      Point(baseX + uy * half, baseY - ux * half),
    ],
    tag: 'arrow-head',
  );
}

enum _Side { right, above, belowRight }

class _Label {
  const _Label(this.text, this.anchor, this.radius, this.preferred);

  final String text;
  final Point<double> anchor;
  final double radius;
  final _Side preferred;
}

/// Premier emplacement libre autour de l'ancre : sur des anneaux de plus en
/// plus éloignés, du côté préféré d'abord ; jamais hors de la table ; à
/// défaut, le premier emplacement ramené dans la table.
Rectangle<double> _place(
  _Label label,
  double width,
  Rectangle<double> box,
  List<Rectangle<double>> occupied,
) {
  const sides = _Side.values;
  final order = [label.preferred, ...sides.where((s) => s != label.preferred)];
  Rectangle<double>? first;
  for (var ring = 0; ring < 12; ring++) {
    final gap = label.radius + 2 + ring * 5;
    for (final side in [..._candidates(order, label.anchor, gap, width)]) {
      final candidate = _inside(side, box);
      first ??= candidate;
      final padded = Rectangle<double>(
        candidate.left - _margin,
        candidate.top - _margin,
        candidate.width + 2 * _margin,
        candidate.height + 2 * _margin,
      );
      if (!occupied.any(padded.intersects)) return candidate;
    }
  }
  return first!;
}

List<Rectangle<double>> _candidates(
  List<_Side> order,
  Point<double> anchor,
  double gap,
  double width,
) {
  Rectangle<double> rect(double left, double top) =>
      Rectangle<double>(left, top, width, _labelSize);
  final centerTop = anchor.y - _labelSize / 2;
  final byDirection = <Rectangle<double>>[
    rect(anchor.x + gap, centerTop),
    rect(anchor.x - gap - width, centerTop),
    rect(anchor.x - width / 2, anchor.y - gap - _labelSize),
    rect(anchor.x - width / 2, anchor.y + gap),
    rect(anchor.x + gap, anchor.y - gap - _labelSize / 2),
    rect(anchor.x + gap, anchor.y + gap - _labelSize / 2),
    rect(anchor.x - gap - width, anchor.y - gap - _labelSize / 2),
    rect(anchor.x - gap - width, anchor.y + gap - _labelSize / 2),
  ];
  final preferred = switch (order.first) {
    _Side.right => byDirection[0],
    _Side.above => byDirection[2],
    _Side.belowRight => rect(anchor.x + 2, anchor.y + 2),
  };
  return [preferred, ...byDirection];
}

Rectangle<double> _inside(Rectangle<double> r, Rectangle<double> box) {
  final left = r.left
      .clamp(box.left, math.max(box.left, box.right - r.width))
      .toDouble();
  final top = r.top
      .clamp(box.top, math.max(box.top, box.bottom - r.height))
      .toDouble();
  return Rectangle<double>(left, top, r.width, r.height);
}
