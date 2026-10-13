import 'dart:math' as math;

import 'model.dart';

/// Rayon d'une bille de couleur [color] (blanche plus petite).
double _radiusOf(String color) =>
    color == 'white' ? cueBallRadius : objectBallRadius;

/// Avertissements de placement des billes initiales : bille hors table
/// (centre en dehors de la surface de jeu), bille qui mord sur une bande ou
/// billes qui se chevauchent.
///
/// Le seuil de chevauchement dépend des couleurs : blanche - bille de but
/// `r_c + r_o` (0,2136), deux billes de but `2 r_o` (0,2197). Une tolérance
/// de [placementTolerance] (0,01 case) absorbe la précision de transcription
/// des diagrammes `[S]`.
List<String> placementWarnings(Json diagram) {
  final out = <String>[];
  final placed = <(String, String, List<double>)>[];
  for (final b in mapsOf(diagram, 'balls')) {
    final p = pointOf(b['at']);
    if (p == null) continue;
    final id = '${b['id']}';
    final color = '${b['color']}';
    placed.add((id, color, p));
    final outside =
        p[0] < 0 || p[0] > tableLength || p[1] < 0 || p[1] > tableWidth;
    if (outside) {
      out.add('bille $id hors table ${fmtPoint(p)}');
      continue;
    }
    final r = _radiusOf(color);
    final depth = [
      r - p[0],
      p[0] + r - tableLength,
      r - p[1],
      p[1] + r - tableWidth,
    ].reduce(math.max);
    if (depth > placementTolerance) {
      out.add(
        'bille $id mord sur la bande de ${depth.toStringAsFixed(3)} case '
        '(rayon ${r.toStringAsFixed(4)}) ${fmtPoint(p)}',
      );
    }
  }
  for (var i = 0; i < placed.length; i++) {
    for (var j = i + 1; j < placed.length; j++) {
      final a = placed[i].$3;
      final b = placed[j].$3;
      final d = math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));
      final limit =
          _radiusOf(placed[i].$2) +
          _radiusOf(placed[j].$2) -
          placementTolerance;
      if (d < limit) {
        out.add(
          'billes ${placed[i].$1} et ${placed[j].$1} se chevauchent '
          '(distance ${d.toStringAsFixed(4)} < ${limit.toStringAsFixed(4)})',
        );
      }
    }
  }
  return out;
}
