import 'dart:math' as math;

import 'model.dart';

/// Avertissements de placement des billes initiales : bille hors table
/// (centre en dehors de la surface de jeu) ou billes qui se chevauchent.
List<String> placementWarnings(Json diagram) {
  final out = <String>[];
  final placed = <(String, List<double>)>[];
  for (final b in mapsOf(diagram, 'balls')) {
    final p = pointOf(b['at']);
    if (p == null) continue;
    final id = '${b['id']}';
    placed.add((id, p));
    final outside =
        p[0] < 0 || p[0] > tableLength || p[1] < 0 || p[1] > tableWidth;
    if (outside) out.add('bille $id hors table ${fmtPoint(p)}');
  }
  for (var i = 0; i < placed.length; i++) {
    for (var j = i + 1; j < placed.length; j++) {
      final a = placed[i].$2;
      final b = placed[j].$2;
      final d = math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));
      if (d < 2 * ballRadius - 1e-9) {
        out.add(
          'billes ${placed[i].$1} et ${placed[j].$1} se chevauchent '
          '(distance ${d.toStringAsFixed(2)} < ${2 * ballRadius})',
        );
      }
    }
  }
  return out;
}
