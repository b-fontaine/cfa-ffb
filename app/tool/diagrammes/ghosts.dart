import 'dart:math' as math;

import 'package:yaml/yaml.dart';

import 'model.dart';

/// Centre de la bille fantôme : `G = O - s · unit(P - O)` avec
/// `s = r_c + r_o` (la bille fantôme est une blanche posée au contact de la
/// bille de but). Une bille sur la poche garde sa position.
List<double> ghostCenter(List<double> object, List<double> pocket) {
  final dx = pocket[0] - object[0];
  final dy = pocket[1] - object[1];
  final length = math.sqrt(dx * dx + dy * dy);
  if (length == 0) return [object[0], object[1]];
  const s = cueBallRadius + objectBallRadius;
  return [object[0] - s * dx / length, object[1] - s * dy / length];
}

/// Une bille fantôme `impact` qui doit être calculée (`G`) et ne l'est pas.
class GhostMismatch {
  const GhostMismatch({
    required this.diagram,
    required this.ghost,
    required this.at,
    required this.expected,
    required this.hit,
    required this.pocket,
  });

  final String diagram;
  final String ghost;
  final List<double> at;
  final List<double> expected;
  final String hit;
  final String pocket;

  double get gap => math.sqrt(
    math.pow(at[0] - expected[0], 2) + math.pow(at[1] - expected[1], 2),
  );

  @override
  String toString() =>
      '$diagram : cercle $ghost en ${fmtPoint(at)}, attendu '
      '${fmtPoint(expected.map((v) => (v * 100).round() / 100).toList())} '
      '($hit vers $pocket ; écart ${gap.toStringAsFixed(3)})';
}

/// Distance maximale entre le `G` attendu d'un tir et le cercle `impact` qui
/// lui correspond pour qu'ils soient associés.
const _matchDistance = 0.1;

/// Vérifie, pour un fichier de **proposition** (`source.rank: Prop`), que
/// chaque cercle `impact` associé à un tir (bille touchée + poche) est au
/// `G` calculé, à [tolerance] près (précision de transcription, 0,01 case).
/// Un fichier transcrit d'un PDF (`rank: S`) n'est jamais contrôlé : ses
/// positions sont des mesures (rang 1).
List<GhostMismatch> ghostMismatches(
  String yamlText, {
  double tolerance = 0.01,
}) {
  final doc = toPlain(loadYaml(yamlText));
  if (doc is! Map<String, Object?>) return const [];
  final source = doc['source'];
  if (source is! Map<String, Object?> || source['rank'] != 'Prop') {
    return const [];
  }
  final out = <GhostMismatch>[];
  for (final d in mapsOf(doc, 'diagrams')) {
    final positions = <String, List<double>>{};
    for (final b in mapsOf(d, 'balls')) {
      final p = pointOf(b['at']);
      if (p != null) positions['${b['id']}'] = p;
    }
    final impacts = <(String, List<double>)>[];
    for (final g in mapsOf(d, 'ghosts')) {
      final p = pointOf(g['at']);
      if (g['role'] == 'impact' && p != null) impacts.add(('${g['id']}', p));
    }
    for (final step in mapsOf(d, 'sequence')) {
      final hit = positions['${step['hit']}'];
      final pocket = pockets['${step['pocket']}'];
      if (hit == null || pocket == null) continue;
      final expected = ghostCenter(hit, pocket);
      (String, List<double>)? nearest;
      var best = _matchDistance;
      for (final candidate in impacts) {
        final distance = math.sqrt(
          math.pow(candidate.$2[0] - expected[0], 2) +
              math.pow(candidate.$2[1] - expected[1], 2),
        );
        if (distance <= best) {
          best = distance;
          nearest = candidate;
        }
      }
      if (nearest == null || best <= tolerance) continue;
      out.add(
        GhostMismatch(
          diagram: '${d['id']}',
          ghost: nearest.$1,
          at: nearest.$2,
          expected: expected,
          hit: '${step['hit']}',
          pocket: '${step['pocket']}',
        ),
      );
    }
  }
  return out;
}
