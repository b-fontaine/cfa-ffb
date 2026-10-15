import 'dart:math' as math;
import 'dart:ui';

/// Les seize positions d'une étiquette autour de son point d'ancrage, dans
/// l'ordre de préférence (la première libre est retenue) : les huit points
/// cardinaux d'abord, puis les huit positions intermédiaires. `dx` et `dy`
/// valent -1, -0,5, 0, 0,5 ou 1 : le côté de l'ancrage où l'étiquette est
/// posée (±0,5 : décalée d'une demi-étiquette le long du côté).
enum LabelSlot {
  northEast(1, -1),
  east(1, 0),
  southEast(1, 1),
  northWest(-1, -1),
  west(-1, 0),
  southWest(-1, 1),
  north(0, -1),
  south(0, 1),
  northNorthEast(0.5, -1),
  eastNorthEast(1, -0.5),
  eastSouthEast(1, 0.5),
  southSouthEast(0.5, 1),
  southSouthWest(-0.5, 1),
  westSouthWest(-1, 0.5),
  westNorthWest(-1, -0.5),
  northNorthWest(-0.5, -1);

  LabelSlot(this.dx, this.dy);

  final double dx;
  final double dy;
}

/// Coût d'une collision avec le bord de la zone : prohibitif.
const int _edgeCost = 1000;

/// Coût d'un recouvrement avec une bille, un cercle ou un autre objet posé :
/// bien plus lourd qu'un croisement de trait, que le halo de l'étiquette
/// compense.
const int _objectCost = 50;

/// Coût du croisement d'un trait (un par segment).
const int _pathCost = 1;

/// Étiquette à poser : [anchor] est le centre de l'objet qu'elle nomme (bille,
/// cercle, point), [anchorRadius] son rayon (0 pour un simple point), [size]
/// l'encombrement du texte, tous en pixels. [alternatives] sont des
/// encombrements du même texte, de plus en plus étroits (donc plus hauts :
/// passage à la ligne), essayés quand aucune position n'est libre à [size].
class LabelRequest {
  const LabelRequest({
    required this.anchor,
    required this.size,
    this.anchorRadius = 0,
    this.alternatives = const [],
  });

  final Offset anchor;
  final Size size;
  final double anchorRadius;
  final List<Size> alternatives;
}

/// Disque à ne pas recouvrir (bille, cercle creux), en pixels.
class LabelDisc {
  const LabelDisc(this.center, this.radius);

  final Offset center;
  final double radius;
}

/// Emplacement retenu pour une étiquette.
class LabelPlacement {
  const LabelPlacement({required this.rect, required this.crowded});

  /// Rectangle de l'étiquette, en pixels.
  final Rect rect;

  /// Vrai si aucune position n'est libre : l'étiquette recouvre un trait ou un
  /// objet et doit être posée sur un halo pour rester lisible.
  final bool crowded;
}

/// Place chaque étiquette de [labels] (dans l'ordre : les premières sont les
/// plus prioritaires) sans qu'elle croise un trait de [paths], un disque de
/// [discs], le bord de [bounds] ni une étiquette déjà placée.
///
/// Fonction pure et déterministe : pour chaque étiquette (à sa taille, puis aux
/// tailles plus étroites de [LabelRequest.alternatives]), seize positions
/// ([LabelSlot], ordre fixe) sont essayées à une distance de l'ancrage de plus
/// en plus grande (anneaux), glissée vers l'intérieur si elle sort de la zone
/// et qu'elle y tient ; la première libre l'emporte. Si aucune ne l'est,
/// la moins gênante est retenue (premier ex æquo dans l'ordre d'essai) et
/// marquée [LabelPlacement.crowded]. Le bord coûte plus qu'un recouvrement de
/// bille, de cercle ou d'objet de [obstacles], qui coûte lui-même plus que le
/// croisement d'un trait (le halo rend lisible une étiquette posée sur un
/// trait, pas sur une bille ou une autre étiquette).
List<LabelPlacement> placeLabels({
  required List<LabelRequest> labels,
  required Rect bounds,
  List<List<Offset>> paths = const [],
  List<LabelDisc> discs = const [],
  List<Rect> obstacles = const [],
  double gap = 2,
  double clearance = 1,
  int rings = 4,
}) {
  final placed = <Rect>[...obstacles];
  final result = <LabelPlacement>[];
  for (final label in labels) {
    Rect? best;
    var bestCost = 1 << 30;
    var free = false;
    search:
    for (final size in [label.size, ...label.alternatives]) {
      for (var ring = 0; ring < rings; ring++) {
        final distance = label.anchorRadius + gap + ring * size.height;
        for (final slot in LabelSlot.values) {
          final rect = _within(_candidate(label, size, slot, distance), bounds);
          final cost = _collisions(
            rect,
            bounds,
            paths,
            discs,
            placed,
            clearance,
          );
          if (cost == 0) {
            best = rect;
            free = true;
            break search;
          }
          if (cost < bestCost) {
            best = rect;
            bestCost = cost;
          }
        }
      }
    }
    placed.add(best!);
    result.add(LabelPlacement(rect: best, crowded: !free));
  }
  return result;
}

/// Emplacement de [bounds] où poser un bloc de taille [size] (bloc qui n'est
/// pas une étiquette : médaillon), à [margin] du bord : d'abord les coins (bas
/// droite, bas gauche, haut droite, haut gauche), puis des positions
/// intermédiaires le long des bords (bas, haut, droite, gauche, par demi-bloc).
/// Retient le premier emplacement qui ne croise aucun trait de [paths],
/// disque de [discs] ni rectangle de [obstacles] ; `null` si aucun n'est
/// libre : le bloc ne recouvre jamais rien.
Rect? placeBlock({
  required Size size,
  required Rect bounds,
  List<List<Offset>> paths = const [],
  List<LabelDisc> discs = const [],
  List<Rect> obstacles = const [],
  double margin = 4,
  double clearance = 1,
}) {
  final left = bounds.left + margin;
  final top = bounds.top + margin;
  final right = bounds.right - margin - size.width;
  final bottom = bounds.bottom - margin - size.height;
  final stepX = math.max(size.width / 2, 1);
  final stepY = math.max(size.height / 2, 1);
  final origins = <Offset>[
    Offset(right, bottom),
    Offset(left, bottom),
    Offset(right, top),
    Offset(left, top),
    for (var x = right - stepX; x > left; x -= stepX) Offset(x, bottom),
    for (var x = right - stepX; x > left; x -= stepX) Offset(x, top),
    for (var y = bottom - stepY; y > top; y -= stepY) Offset(right, y),
    for (var y = bottom - stepY; y > top; y -= stepY) Offset(left, y),
  ];
  for (final origin in origins) {
    final rect = origin & size;
    if (_collisions(rect, bounds, paths, discs, obstacles, clearance) == 0) {
      return rect;
    }
  }
  return null;
}

/// [rect] ramené dans [bounds] (glissé vers l'intérieur) s'il y tient ; trop
/// large ou trop haut, il est rendu tel quel et paie le coût du bord.
Rect _within(Rect rect, Rect bounds) {
  var dx = 0.0;
  var dy = 0.0;
  if (rect.width <= bounds.width) {
    if (rect.left < bounds.left) dx = bounds.left - rect.left;
    if (rect.right > bounds.right) dx = bounds.right - rect.right;
  }
  if (rect.height <= bounds.height) {
    if (rect.top < bounds.top) dy = bounds.top - rect.top;
    if (rect.bottom > bounds.bottom) dy = bounds.bottom - rect.bottom;
  }
  return dx == 0 && dy == 0 ? rect : rect.shift(Offset(dx, dy));
}

Rect _candidate(
  LabelRequest label,
  Size size,
  LabelSlot slot,
  double distance,
) {
  final w = size.width;
  final h = size.height;
  final center =
      label.anchor +
      Offset(slot.dx * (distance + w / 2), slot.dy * (distance + h / 2));
  return Rect.fromCenter(center: center, width: w, height: h);
}

int _collisions(
  Rect rect,
  Rect bounds,
  List<List<Offset>> paths,
  List<LabelDisc> discs,
  List<Rect> placed,
  double clearance,
) {
  final padded = rect.inflate(clearance);
  var cost = 0;
  if (rect.left < bounds.left ||
      rect.top < bounds.top ||
      rect.right > bounds.right ||
      rect.bottom > bounds.bottom) {
    cost += _edgeCost;
  }
  for (final path in paths) {
    for (var i = 0; i + 1 < path.length; i++) {
      if (_segmentHitsRect(path[i], path[i + 1], padded)) cost += _pathCost;
    }
    if (path.length == 1 && padded.contains(path.single)) cost += _pathCost;
  }
  for (final disc in discs) {
    final nearest = Offset(
      disc.center.dx.clamp(padded.left, padded.right),
      disc.center.dy.clamp(padded.top, padded.bottom),
    );
    if ((nearest - disc.center).distance < disc.radius) cost += _objectCost;
  }
  for (final other in placed) {
    if (padded.overlaps(other)) cost += _objectCost;
  }
  return cost;
}

/// Vrai si le segment [a]-[b] traverse ou touche [rect] (Liang-Barsky).
bool _segmentHitsRect(Offset a, Offset b, Rect rect) {
  var t0 = 0.0;
  var t1 = 1.0;
  final d = b - a;
  bool clip(double p, double q) {
    if (p == 0) return q >= 0;
    final r = q / p;
    if (p < 0) {
      if (r > t1) return false;
      t0 = math.max(t0, r);
    } else {
      if (r < t0) return false;
      t1 = math.min(t1, r);
    }
    return true;
  }

  return clip(-d.dx, a.dx - rect.left) &&
      clip(d.dx, rect.right - a.dx) &&
      clip(-d.dy, a.dy - rect.top) &&
      clip(d.dy, rect.bottom - a.dy);
}

/// Points de [points] dont la dernière pointe est reculée sur le bord du
/// disque de centre [center] et de rayon [radius] quand elle y arrive : la
/// pointe de flèche s'arrête au cercle au lieu de le recouvrir. Les [points]
/// sont rendus tels quels si la pointe est ailleurs ou si le dernier segment
/// est plus court que [radius].
List<Offset> retractTipToCircle(
  List<Offset> points,
  Offset center,
  double radius,
) {
  if (points.length < 2 || (points.last - center).distance > 0.5) {
    return points;
  }
  final previous = points[points.length - 2];
  final length = (points.last - previous).distance;
  if (length <= radius) return points;
  final tip = points.last + (previous - points.last) * (radius / length);
  return [...points.take(points.length - 1), tip];
}
