import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';

// Logique pure (Dart sans Flutter) : à partir d'un `TableDiagramSpec`, calcule
// où se trouve chaque bille à un instant donné.
//
// Règles de lecture du schéma (documentées dans design-system.md) :
//  - chaque tir repart de la position de départ de la blanche (cercle
//    `cue_start` nommé par `fromGhostId`, sinon départ de la flèche choisie,
//    sinon position initiale) ; la bille touchée est remise en place ;
//  - la flèche de la blanche est celle qui part du cercle nommé ou, à défaut,
//    celle qui finit le plus près de la bille touchée (à 0,6 case au plus) ;
//    sans flèche, la blanche vise en ligne droite un point situé deux rayons
//    derrière la bille, dans l'axe de la poche ;
//  - la blanche s'arrête au contact, puis la bille touchée suit sa flèche
//    jusqu'à la poche et disparaît ;
//  - un tir sans bille touchée (`hitId` nul) déplace la bille jouée le long de
//    sa flèche ;
//  - les `repeat` ne sont pas déroulés : un tir est joué une seule fois ;
//  - un point hors de la table est refusé (`InvalidDiagramException`), pas
//    borné ; seules les flèches d'indication (ligne de visée) peuvent
//    dépasser la bande.

/// Schéma invalide : erreur de transcription (bille ou cercle inconnu, point
/// hors de la table). L'appelant affiche un état d'erreur localisé.
class InvalidDiagramException implements Exception {
  const InvalidDiagramException(this.message);

  final String message;

  @override
  String toString() => 'InvalidDiagramException: $message';
}

/// Ligne brisée parcourue à vitesse constante.
class DiagramPolyline {
  const DiagramPolyline(this.points);

  final List<DiagramPoint> points;

  /// Longueur totale, en cases.
  double get length {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += points[i - 1].distanceTo(points[i]);
    }
    return total;
  }

  /// Point atteint après [distance] cases (borné au début et à la fin).
  DiagramPoint pointAt(double distance) {
    var remaining = math.max<double>(0, distance);
    for (var i = 1; i < points.length; i++) {
      final segment = points[i - 1].distanceTo(points[i]);
      if (remaining <= segment && segment > 0) {
        return points[i - 1].lerp(points[i], remaining / segment);
      }
      remaining -= segment;
    }
    return points.last;
  }

  /// Direction du premier segment non nul, en radians (sens horaire,
  /// 0 = vers la droite) ; `null` si la ligne n'a pas de longueur.
  double? get startAngle {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (a != b) return math.atan2(b.y - a.y, b.x - a.x);
    }
    return null;
  }
}

/// Un tir déroulé : trajet de la blanche puis trajet de la bille touchée.
class DiagramTimelineStep {
  const DiagramTimelineStep({
    required this.cueId,
    required this.cuePath,
    required this.objectPath,
    required this.pocketed,
    required this.startLength,
    this.hitId,
  });

  final String cueId;

  /// Bille touchée ; `null` quand la bille jouée n'en touche aucune.
  final String? hitId;
  final DiagramPolyline cuePath;
  final DiagramPolyline objectPath;

  /// La bille touchée finit dans une poche.
  final bool pocketed;

  /// Longueur cumulée parcourue avant ce tir.
  final double startLength;

  /// Longueur du tir (blanche + bille touchée).
  double get length => cuePath.length + objectPath.length;
}

/// Position d'une bille à un instant donné.
class DiagramBallState {
  const DiagramBallState({required this.position, this.pocketed = false});

  final DiagramPoint position;

  /// La bille est empochée : elle ne doit plus être dessinée.
  final bool pocketed;
}

/// État de la table à un instant donné.
class DiagramFrame {
  const DiagramFrame({
    required this.balls,
    required this.stepIndex,
    this.cueAngle,
  });

  /// État de chaque bille, par identifiant.
  final Map<String, DiagramBallState> balls;

  /// Tir en cours (`-1` sans déroulé).
  final int stepIndex;

  /// Direction de la queue (radians, sens horaire, 0 = vers la droite) tant
  /// que la blanche n'a pas bougé ; `null` ensuite.
  final double? cueAngle;
}

/// Déroulé animable d'un schéma.
class DiagramTimeline {
  DiagramTimeline._({
    required this.spec,
    required this.steps,
    required this.totalLength,
    required this.casesPerSecond,
  });

  /// Construit le déroulé de [spec]. Lève une [InvalidDiagramException] si un
  /// tir cite une bille ou un cercle inconnu, ou si un point du schéma sort de
  /// la table ([0, 8] x [0, 4], bords compris) : erreur de transcription,
  /// jamais bornée en silence.
  factory DiagramTimeline.from(
    TableDiagramSpec spec, {
    double casesPerSecond = 3,
  }) {
    _checkInsideTable(spec);
    final balls = {for (final b in spec.balls) b.id: b};
    final ghosts = {for (final g in spec.ghosts) g.id: g};
    final steps = <DiagramTimelineStep>[];
    var cumulated = 0.0;
    for (final step in spec.steps) {
      final cue = balls[step.cueId];
      final hit = step.hitId == null ? null : balls[step.hitId];
      if (cue == null || (step.hitId != null && hit == null)) {
        throw InvalidDiagramException(
          'Tir inconnu : bille ${cue == null ? step.cueId : step.hitId} '
          'absente de ${spec.id}.',
        );
      }
      DiagramGhost? from;
      if (step.fromGhostId != null) {
        from = ghosts[step.fromGhostId];
        if (from == null) {
          throw InvalidDiagramException(
            'Cercle ${step.fromGhostId} absent de ${spec.id}.',
          );
        }
      }
      final built = _buildStep(spec, step, cue, hit, from, cumulated);
      steps.add(built);
      cumulated += built.length;
    }
    return DiagramTimeline._(
      spec: spec,
      steps: steps,
      totalLength: cumulated,
      casesPerSecond: casesPerSecond,
    );
  }

  /// Déroulé de [spec], calculé une seule fois par instance de schéma.
  /// Mêmes erreurs que [DiagramTimeline.from].
  factory DiagramTimeline.of(TableDiagramSpec spec) =>
      _cache[spec] ??= DiagramTimeline.from(spec);

  static final _cache = Expando<DiagramTimeline>('DiagramTimeline');

  /// Écart maximal toléré entre la fin d'une flèche de la blanche et la bille
  /// touchée pour que la flèche soit retenue, en cases.
  static const double _arrowTolerance = 0.6;

  /// Écart maximal entre le début d'une flèche et son cercle de départ.
  static const double _ghostTolerance = 0.2;

  static const double _epsilon = 1e-9;

  final TableDiagramSpec spec;
  final List<DiagramTimelineStep> steps;

  /// Longueur totale parcourue, en cases.
  final double totalLength;

  /// Vitesse de la bille, en cases par seconde (à ×1).
  final double casesPerSecond;

  /// Aucun tir à dérouler.
  bool get isEmpty => steps.isEmpty;

  /// Durée de lecture à ×1.
  Duration get duration =>
      Duration(milliseconds: (totalLength / casesPerSecond * 1000).round());

  /// Table avant le premier tir.
  DiagramFrame get initialFrame => frameAt(0);

  /// Table après le dernier tir.
  DiagramFrame get finalFrame => frameAt(1);

  /// État à l'instant [elapsed] (borné à la durée).
  DiagramFrame frameAtTime(Duration elapsed) {
    final total = duration.inMicroseconds;
    if (total == 0) return finalFrame;
    return frameAt(elapsed.inMicroseconds / total);
  }

  /// État à l'avancement [t] ∈ [0, 1] (vitesse constante sur le tracé).
  DiagramFrame frameAt(double t) {
    final d = totalLength * t.clamp(0.0, 1.0);
    final balls = {
      for (final b in spec.balls) b.id: DiagramBallState(position: b.at),
    };
    var active = -1;
    double? cueAngle;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.startLength > d) break;
      active = i;
      // La tolérance absorbe l'erreur d'arrondi des longueurs cumulées.
      final done = d >= step.startLength + step.length - _epsilon;
      final local = done ? step.length : d - step.startLength;
      final cueDistance = math.min(local, step.cuePath.length);
      final objectDistance = math.max<double>(0, local - step.cuePath.length);
      balls[step.cueId] = DiagramBallState(
        position: step.cuePath.pointAt(cueDistance),
      );
      final hitId = step.hitId;
      if (hitId != null) {
        balls[hitId] = DiagramBallState(
          position: step.objectPath.pointAt(objectDistance),
          pocketed: step.pocketed && local >= step.length,
        );
      }
      cueAngle = local == 0 ? step.cuePath.startAngle : null;
    }
    return DiagramFrame(balls: balls, stepIndex: active, cueAngle: cueAngle);
  }

  static void _checkInsideTable(TableDiagramSpec spec) {
    void check(String what, DiagramPoint p) {
      if (p.x < 0 ||
          p.x > DiagramLayout.columns ||
          p.y < 0 ||
          p.y > DiagramLayout.rows) {
        throw InvalidDiagramException(
          'Point hors table : $what en (${p.x}, ${p.y}) dans ${spec.id}.',
        );
      }
    }

    for (final b in spec.balls) {
      check('bille ${b.id}', b.at);
    }
    for (final g in spec.ghosts) {
      check('cercle ${g.id}', g.at);
    }
    for (final a in spec.arrows) {
      if (a.kind == DiagramArrowKind.indication) continue;
      for (final p in a.path) {
        check('flèche ${a.id}', p);
      }
    }
  }

  static DiagramTimelineStep _buildStep(
    TableDiagramSpec spec,
    DiagramStep step,
    DiagramBall cue,
    DiagramBall? hit,
    DiagramGhost? from,
    double startLength,
  ) {
    if (hit == null) return _soloStep(spec, cue, from, startLength);
    final arrow = _cueArrow(spec, step, hit, from);
    final start = from?.at ?? arrow?.path.first ?? cue.at;
    final objectArrow = _objectArrow(spec, hit.id);
    final pocket = step.pocket ?? objectArrow?.pocket;

    final cuePoints = arrow != null
        ? [start, ...arrow.path.skip(1)]
        : [start, _impactPoint(start, hit.at, pocket)];

    return DiagramTimelineStep(
      cueId: cue.id,
      hitId: hit.id,
      cuePath: DiagramPolyline(cuePoints),
      objectPath: DiagramPolyline(_objectPoints(hit, objectArrow, pocket)),
      pocketed: pocket != null,
      startLength: startLength,
    );
  }

  /// Tir sans bille touchée : la bille jouée suit sa flèche (de blanche, sinon
  /// de bille visée) et s'arrête à son extrémité ; sans flèche, elle ne bouge
  /// pas.
  static DiagramTimelineStep _soloStep(
    TableDiagramSpec spec,
    DiagramBall cue,
    DiagramGhost? from,
    double startLength,
  ) {
    DiagramArrow? arrow;
    for (final kind in [DiagramArrowKind.cue, DiagramArrowKind.object]) {
      for (final a in spec.arrows) {
        if (arrow == null &&
            a.kind == kind &&
            a.ballId == cue.id &&
            a.path.length >= 2) {
          arrow = a;
        }
      }
    }
    final start = from?.at ?? arrow?.path.first ?? cue.at;
    final cuePoints = [start, ...?arrow?.path.skip(1)];
    return DiagramTimelineStep(
      cueId: cue.id,
      cuePath: DiagramPolyline(cuePoints),
      objectPath: DiagramPolyline([cuePoints.last]),
      pocketed: false,
      startLength: startLength,
    );
  }

  static DiagramArrow? _cueArrow(
    TableDiagramSpec spec,
    DiagramStep step,
    DiagramBall hit,
    DiagramGhost? from,
  ) {
    final candidates = [
      for (final a in spec.arrows)
        if (a.kind == DiagramArrowKind.cue &&
            a.ballId == step.cueId &&
            a.path.length >= 2)
          a,
    ];
    DiagramArrow? best;
    var bestDistance = double.infinity;
    for (final a in candidates) {
      final distance = from != null
          ? a.path.first.distanceTo(from.at)
          : a.path.last.distanceTo(hit.at);
      final limit = from != null ? _ghostTolerance : _arrowTolerance;
      if (distance <= limit && distance < bestDistance) {
        best = a;
        bestDistance = distance;
      }
    }
    return best;
  }

  static DiagramArrow? _objectArrow(TableDiagramSpec spec, String hitId) {
    for (final a in spec.arrows) {
      if (a.kind == DiagramArrowKind.object &&
          a.ballId == hitId &&
          a.path.length >= 2) {
        return a;
      }
    }
    return null;
  }

  /// Centre de la blanche au contact : deux rayons derrière la bille touchée,
  /// dans l'axe de la poche (la bille part selon la ligne des centres) ou, sans
  /// poche, dans l'axe de la visée.
  static DiagramPoint _impactPoint(
    DiagramPoint start,
    DiagramPoint target,
    DiagramPocket? pocket,
  ) {
    final towards = pocket != null && pocket.point != target
        ? pocket.point
        : target;
    final origin = pocket != null && pocket.point != target ? target : start;
    final length = origin.distanceTo(towards);
    if (length == 0) return start;
    final ux = (towards.x - origin.x) / length;
    final uy = (towards.y - origin.y) / length;
    return DiagramPoint(
      target.x - ux * 2 * DiagramLayout.ballRadius,
      target.y - uy * 2 * DiagramLayout.ballRadius,
    );
  }

  static List<DiagramPoint> _objectPoints(
    DiagramBall hit,
    DiagramArrow? arrow,
    DiagramPocket? pocket,
  ) {
    final points = [hit.at, ...?arrow?.path.skip(1)];
    if (pocket == null) return points;
    final end = pocket.point;
    if (points.length > 1 && points.last.distanceTo(end) <= _arrowTolerance) {
      points[points.length - 1] = end;
    } else {
      points.add(end);
    }
    return points;
  }
}
