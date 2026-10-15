import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/player_figure_layout.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

export 'package:billard_cfa/shared/lib/player_figure_layout.dart'
    show CueBridge, Handedness, HeadCase, LeadEye, PlayerMark, PlayerView;

/// Joueur schématique, droitier : un pictogramme neutre (pas de visage, de
/// sexe ni d'âge) de profil, de dessus ou des deux, avec des repères
/// numérotés et légendés (fiche technique n° 1, étape 2).
///
/// Les billes sont **agrandies** et non à l'échelle (la description parlée le
/// dit). La légende est une liste hors du dessin, lisible en projection ; un
/// repère hors de [focus] est estompé et sans ligne de légende. La
/// géométrie est dans `PlayerFigureLayout` (`SidePose`, `TopPose`) ; pour un
/// gaucher ([handedness]), le dessin est mis en miroir et la légende
/// inverse les côtés.
class PlayerFigure extends StatelessWidget {
  const PlayerFigure({
    this.view = PlayerView.side,
    this.focus = PlayerMark.values,
    this.leadEye,
    this.headCase,
    this.bridge = CueBridge.frame,
    this.handedness = Handedness.right,
    super.key,
  });

  final PlayerView view;

  /// Droitier (pose calculée) ou gaucher (pose en miroir).
  final Handedness handedness;

  /// Repères présentés ; les autres sont estompés et sans légende.
  final List<PlayerMark> focus;

  /// Œil directeur à marquer d'une cible, vue de dessus ; absent, il se déduit
  /// de [headCase] (l'œil placé au-dessus de la queue) et aucun œil n'est
  /// marqué quand la queue est entre les deux yeux.
  final LeadEye? leadEye;

  /// L'œil marqué d'une cible : [leadEye], sinon celui de [headCase].
  LeadEye? get markedEye =>
      leadEye ??
      switch (headCase) {
        HeadCase.rightEyeOverCue => LeadEye.right,
        HeadCase.leftEyeOverCue => LeadEye.left,
        HeadCase.cueBetweenEyes || null => null,
      };

  /// Place de la tête, vue de dessus.
  final HeadCase? headCase;

  /// Appui de la main de chevalet.
  final CueBridge bridge;

  /// Largeur à partir de laquelle les deux vues sont côte à côte.
  static const double _wide = 640;

  /// Côté d'une pastille, en pixels.
  static const double badgeSize = 28;

  /// Texte de légende de [mark] pour un appui de [bridge] et une
  /// latéralité [handedness] (les côtés s'inversent pour un gaucher).
  static String markText(
    AppLocalizations l10n,
    PlayerMark mark,
    CueBridge bridge, [
    Handedness handedness = Handedness.right,
  ]) => switch (mark) {
    PlayerMark.feet => switch (handedness) {
      Handedness.right => l10n.playerMarkFeet,
      Handedness.left => l10n.playerMarkFeetLeft,
    },
    PlayerMark.legsAndHips => switch (handedness) {
      Handedness.right => l10n.playerMarkLegs,
      Handedness.left => l10n.playerMarkLegsLeft,
    },
    PlayerMark.head => l10n.playerMarkHead,
    PlayerMark.backForearm => l10n.playerMarkForearm,
    PlayerMark.bridgeHand => l10n.playerMarkBridge(switch (bridge) {
      CueBridge.frame => l10n.playerBridgeFrame,
      CueBridge.surface => l10n.playerBridgeSurface,
    }),
    PlayerMark.cue => l10n.playerMarkCue,
  };

  static String headCaseText(AppLocalizations l10n, HeadCase c) => switch (c) {
    HeadCase.rightEyeOverCue => l10n.headCaseRightEye,
    HeadCase.cueBetweenEyes => l10n.headCaseBetweenEyes,
    HeadCase.leftEyeOverCue => l10n.headCaseLeftEye,
  };

  bool get _hasSide => view != PlayerView.top;
  bool get _hasTop => view != PlayerView.side;

  /// Repères légendés : dans l'ordre numérique, hors de ceux qu'aucune des
  /// vues présentées ne montre (l'avant-bras ne se lit pas de dessus).
  List<PlayerMark> get _legended => [
    for (final mark in PlayerMark.values)
      if (focus.contains(mark) &&
          (_hasSide || TopPose.visibleMarks.contains(mark)))
        mark,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final textStyle = theme.textTheme.bodyMedium;
    final legended = _legended;
    final mirrored = handedness == Handedness.left;
    final viewName = switch (view) {
      PlayerView.side => l10n.playerViewSide,
      PlayerView.top => l10n.playerViewTop,
      PlayerView.both => l10n.playerViewBoth,
    };
    final marks = [
      for (final mark in legended)
        '${mark.number}. ${markText(l10n, mark, bridge, handedness)}',
    ];
    final eye = markedEye;
    final leadEyeShown =
        _hasTop && focus.contains(PlayerMark.head) && eye != null;
    final leadEyeName = eye == LeadEye.left
        ? l10n.leadEyeLeft
        : l10n.leadEyeRight;

    Widget side() => _Figure(
      key: const ValueKey('player-figure-side'),
      aspect: SidePose.aspect,
      painter: (colors) =>
          _SidePainter(bridge: bridge, focus: focus, colors: colors),
      badges: [
        for (final mark in PlayerMark.values)
          (
            mark: mark,
            at: _mirror(
              _toUnit(SidePose.of(bridge).badgeOf(mark)),
              x: mirrored,
            ),
          ),
      ],
      focus: focus,
      flipX: mirrored,
    );
    Widget top() => _Figure(
      key: const ValueKey('player-figure-top'),
      aspect: TopPose.aspect,
      painter: (colors) => _TopPainter(
        focus: focus,
        leadEye: markedEye,
        headCase: headCase,
        bridge: bridge,
        colors: colors,
      ),
      badges: [
        for (final mark in TopPose.visibleMarks)
          (
            mark: mark,
            at: _mirror(
              Offset(TopPose.badgeOf(mark).x, TopPose.badgeOf(mark).y),
              y: mirrored,
            ),
          ),
      ],
      focus: focus,
      flipY: mirrored,
    );

    return Semantics(
      label: mirrored
          ? l10n.playerFigureLeftLabel(viewName, marks.join('. '))
          : l10n.playerFigureLabel(viewName, marks.join('. ')),
      container: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (view == PlayerView.side) return Center(child: side());
              if (view == PlayerView.top) return top();
              if (constraints.maxWidth >= _wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: side()),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: top()),
                  ],
                );
              }
              return Column(
                children: [
                  side(),
                  const SizedBox(height: AppSpacing.md),
                  top(),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          for (final mark in legended)
            _LegendRow(
              key: ValueKey('player-legend-${mark.number}'),
              number: mark.number,
              text: markText(l10n, mark, bridge, handedness),
            ),
          if (_hasTop && headCase != null)
            Padding(
              key: const ValueKey('player-head-case'),
              padding: const EdgeInsets.only(
                left: badgeSize + AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              child: Text(headCaseText(l10n, headCase!), style: textStyle),
            ),
          if (leadEyeShown)
            Padding(
              key: const ValueKey('player-lead-eye'),
              padding: const EdgeInsets.only(left: badgeSize + AppSpacing.sm),
              child: Text(l10n.playerLeadEye(leadEyeName), style: textStyle),
            ),
        ],
      ),
    );
  }

  /// Miroir d'une position en fractions du cadre : `x` pour la vue de
  /// profil (le gaucher regarde vers la gauche), `y` pour la vue de dessus
  /// (sa droite est en haut).
  static Offset _mirror(Offset at, {bool x = false, bool y = false}) =>
      Offset(x ? 1 - at.dx : at.dx, y ? 1 - at.dy : at.dy);

  /// Position d'un point en unités de H dans le cadre de la vue de profil
  /// (fractions de la largeur et de la hauteur, `y` vers le bas).
  static Offset _toUnit(math.Point<double> p) {
    const f = SidePose.frame;
    return Offset(
      (p.x - f.left) / (f.right - f.left),
      (f.top - p.y) / (f.top - f.bottom),
    );
  }
}

/// Couleurs du dessin, lues dans le thème.
class _FigureColors {
  const _FigureColors({
    required this.background,
    required this.stroke,
    required this.body,
    required this.leader,
    required this.balls,
    required this.table,
    required this.target,
  });

  factory _FigureColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _FigureColors(
      background: scheme.surfaceContainerHighest,
      stroke: scheme.onSurface,
      body: scheme.primary,
      leader: scheme.onSurfaceVariant,
      balls: theme.extension<BallColors>() ?? BallColors.light,
      table: theme.extension<TableColors>() ?? TableColors.light,
      target: (theme.extension<TableColors>() ?? TableColors.light).chalk,
    );
  }

  final Color background;
  final Color stroke;
  final Color body;
  final Color leader;
  final BallColors balls;
  final TableColors table;
  final Color target;
}

typedef _Badge = ({PlayerMark mark, Offset at});

class _Figure extends StatelessWidget {
  const _Figure({
    required this.aspect,
    required this.painter,
    required this.badges,
    required this.focus,
    this.flipX = false,
    this.flipY = false,
    super.key,
  });

  /// Miroir du dessin (gaucher) ; les pastilles sont placées en miroir par
  /// l'appelant, leur chiffre reste lisible.
  final bool flipX;
  final bool flipY;

  final double aspect;
  final CustomPainter Function(_FigureColors colors) painter;
  final List<_Badge> badges;
  final List<PlayerMark> focus;

  @override
  Widget build(BuildContext context) {
    final colors = _FigureColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Transform.flip(
                    flipX: flipX,
                    flipY: flipY,
                    child: CustomPaint(painter: painter(colors)),
                  ),
                ),
                for (final badge in badges)
                  Positioned(
                    left: badge.at.dx * w - PlayerFigure.badgeSize / 2,
                    top: badge.at.dy * h - PlayerFigure.badgeSize / 2,
                    width: PlayerFigure.badgeSize,
                    height: PlayerFigure.badgeSize,
                    child: Opacity(
                      opacity: focus.contains(badge.mark) ? 1 : 0.35,
                      child: _NumberBadge(
                        key: ValueKey('player-badge-${badge.mark.number}'),
                        number: badge.mark.number,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Pastille numérotée : disque cerné, chiffre fixe (≥ 14), jamais tronqué par
/// l'agrandissement du texte système.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, super.key});

  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.onSurface, width: 3),
      ),
      child: Center(
        child: MediaQuery.withNoTextScaling(
          child: Text('$number', style: theme.textTheme.labelLarge),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.number, required this.text, super.key});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: PlayerFigure.badgeSize,
            height: PlayerFigure.badgeSize,
            child: _NumberBadge(number: number),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

// --- vue de profil ---------------------------------------------------------

class _SidePainter extends CustomPainter {
  const _SidePainter({
    required this.bridge,
    required this.focus,
    required this.colors,
  });

  final CueBridge bridge;
  final List<PlayerMark> focus;
  final _FigureColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = SidePose.of(bridge);
    const f = SidePose.frame;
    final unit = size.width / (f.right - f.left);
    Offset at(math.Point<double> p) =>
        Offset((p.x - f.left) * unit, (f.top - p.y) * unit);
    Offset xy(double x, double y) => at(math.Point(x, y));
    double len(double h) => h * unit;
    final line = math.max<double>(3, len(0.012));

    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(unit * 0.05),
        ),
        Paint()..color = colors.background,
      )
      // Sol.
      ..drawLine(xy(f.left, 0), xy(f.right, 0), stroke(colors.leader, line));

    // Table : pieds, plateau, tapis ; rail si le chevalet est sur cadre.
    final legPaint = stroke(colors.table.rail, len(0.025));
    for (final x in [0.88, 1.34]) {
      canvas.drawLine(xy(x, 0.42), xy(x, 0), legPaint);
    }
    final slab = Rect.fromPoints(xy(0.78, 0.48), xy(f.right, 0.42));
    canvas
      ..drawRect(slab, Paint()..color = colors.table.rail)
      ..drawRect(slab, stroke(colors.stroke, line));
    // Le rail va jusqu'au bord de la main de chevalet (qui s'y appuie) ; sur
    // le cadre, la blanche est à 0,10 H de son bord.
    final railRight = bridge == CueBridge.frame
        ? math.max(0.95, pose.bridgeHand.x + SidePose.handRadius)
        : 0.92;
    final cloth = Rect.fromPoints(xy(railRight, 0.48), xy(f.right, 0.465));
    canvas.drawRect(cloth, Paint()..color = colors.balls.cloth);
    if (bridge == CueBridge.frame) {
      final rail = Rect.fromPoints(
        xy(0.78, SidePose.railTop),
        xy(railRight, SidePose.tableTop),
      );
      canvas
        ..drawRect(rail, Paint()..color = colors.table.rail)
        ..drawRect(rail, stroke(colors.stroke, line));
    }

    // Le corps est un pictogramme : chaque membre est cerné puis rempli, ce
    // qui sépare les membres qui se recouvrent. Les membres gauches (côté
    // éloigné) sont dessinés d'abord et plus clairs.
    void limbPath(List<Offset> points, double width, {bool far = false}) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas
        ..drawPath(path, stroke(colors.stroke, width + 2 * line))
        ..drawPath(
          path,
          stroke(
            far
                ? Color.lerp(colors.body, colors.background, 0.45)!
                : colors.body,
            width,
          ),
        );
    }

    limbPath(
      [at(pose.hip), at(pose.leftKnee), at(pose.leftFoot)],
      len(0.05),
      far: true,
    );
    limbPath(
      [at(pose.leftShoulder), at(pose.bridgeHand)],
      len(0.045),
      far: true,
    );
    // Pieds : deux ovales posés au sol.
    for (final foot in [pose.leftFoot, pose.rightFoot]) {
      final rect = Rect.fromCenter(
        center: at(foot).translate(len(0.03), 0),
        width: len(0.12),
        height: len(0.045),
      );
      canvas
        ..drawOval(rect, Paint()..color = colors.body)
        ..drawOval(rect, stroke(colors.stroke, line));
    }
    // Jambe droite, tendue, jusqu'au pied sous la main arrière ; tronc.
    limbPath([at(pose.hip), at(pose.rightFoot)], len(0.05));
    limbPath([at(pose.hip), at(pose.shoulder)], len(0.1));
    // Bras arrière : épaule, coude (à l'aplomb de la main), main.
    limbPath([
      at(pose.shoulder),
      at(pose.elbow),
      at(pose.backHand),
    ], len(0.045));
    // Cou : du haut du tronc à la tête, pour que la tête ne flotte pas.
    limbPath([at(pose.shoulder), at(pose.head)], len(0.05));
    // Tête : un disque, sans visage ; puis la main de chevalet.
    canvas
      ..drawCircle(
        at(pose.head),
        len(SidePose.headRadius),
        Paint()..color = colors.body,
      )
      ..drawCircle(
        at(pose.head),
        len(SidePose.headRadius),
        stroke(colors.stroke, line),
      )
      ..drawCircle(
        at(pose.bridgeHand),
        len(SidePose.handRadius),
        Paint()..color = colors.body,
      )
      ..drawCircle(
        at(pose.bridgeHand),
        len(SidePose.handRadius),
        stroke(colors.stroke, line),
      );

    // Queue : du talon (épais) à la pointe, au contact de la blanche.
    _cue(canvas, at(pose.butt), at(pose.tip), len(0.03), len(0.012), line);
    canvas
      ..drawCircle(at(pose.backHand), len(0.022), Paint()..color = colors.body)
      ..drawCircle(at(pose.backHand), len(0.022), stroke(colors.stroke, line));
    paintBilliardBall(
      canvas,
      center: at(pose.ballCenter),
      radius: len(SidePose.drawnBallRadius),
      fill: colors.balls.white,
      balls: colors.balls,
      table: colors.table,
    );

    // Traits de renvoi des pastilles.
    for (final mark in PlayerMark.values) {
      if (!focus.contains(mark)) continue;
      canvas
        ..drawLine(
          at(pose.badgeOf(mark)),
          at(pose.targetOf(mark)),
          stroke(colors.leader, line),
        )
        ..drawCircle(
          at(pose.targetOf(mark)),
          line * 1.1,
          Paint()..color = colors.stroke,
        );
    }
  }

  void _cue(
    Canvas canvas,
    Offset butt,
    Offset tip,
    double buttWidth,
    double tipWidth,
    double line,
  ) {
    final d = tip - butt;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final body = Path()
      ..moveTo(butt.dx + n.dx * buttWidth / 2, butt.dy + n.dy * buttWidth / 2)
      ..lineTo(tip.dx + n.dx * tipWidth / 2, tip.dy + n.dy * tipWidth / 2)
      ..lineTo(tip.dx - n.dx * tipWidth / 2, tip.dy - n.dy * tipWidth / 2)
      ..lineTo(butt.dx - n.dx * buttWidth / 2, butt.dy - n.dy * buttWidth / 2)
      ..close();
    canvas
      ..drawPath(body, Paint()..color = colors.table.cueWood)
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..strokeJoin = StrokeJoin.round
          ..color = colors.table.cueButt,
      );
    // Talon : le quart de la queue le plus proche de la main arrière.
    final end = butt + d * 0.25;
    final w = buttWidth + (tipWidth - buttWidth) * 0.25;
    final grip = Path()
      ..moveTo(butt.dx + n.dx * buttWidth / 2, butt.dy + n.dy * buttWidth / 2)
      ..lineTo(end.dx + n.dx * w / 2, end.dy + n.dy * w / 2)
      ..lineTo(end.dx - n.dx * w / 2, end.dy - n.dy * w / 2)
      ..lineTo(butt.dx - n.dx * buttWidth / 2, butt.dy - n.dy * buttWidth / 2)
      ..close();
    canvas.drawPath(grip, Paint()..color = colors.table.cueButt);
  }

  @override
  bool shouldRepaint(_SidePainter old) =>
      old.bridge != bridge || old.focus != focus || old.colors != colors;
}

// --- vue de dessus ---------------------------------------------------------

class _TopPainter extends CustomPainter {
  const _TopPainter({
    required this.focus,
    required this.leadEye,
    required this.headCase,
    required this.bridge,
    required this.colors,
  });

  final List<PlayerMark> focus;
  final LeadEye? leadEye;
  final HeadCase? headCase;
  final CueBridge bridge;
  final _FigureColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset at(math.Point<double> p) => Offset(p.x * w, p.y * h);
    final line = math.max<double>(3, h * 0.02);

    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final head = TopPose.headCentre(headCase);
    final far = Color.lerp(colors.body, colors.background, 0.45)!;

    // Un membre : cerné puis rempli, pour séparer ce qui se recouvre.
    void limb(Offset a, Offset b, double width, {Color? color}) {
      canvas
        ..drawLine(a, b, stroke(colors.stroke, width + 2 * line))
        ..drawLine(a, b, stroke(color ?? colors.body, width));
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h * 0.06)),
      Paint()..color = colors.background,
    );
    // Bord de la table : le rail (sur lequel la main s'appuie, chevalet sur
    // cadre) puis le tapis où est la blanche.
    final (railFrom, railTo) = TopPose.railSpan(bridge);
    final railRect = Rect.fromLTRB(railFrom * w, 0, railTo * w, h);
    canvas
      ..drawRect(
        Rect.fromLTRB(railTo * w, 0, w, h),
        Paint()..color = colors.balls.cloth,
      )
      ..drawRect(railRect, Paint()..color = colors.table.rail)
      ..drawRect(railRect, stroke(colors.stroke, line));
    // Axe de visée, en pointillés.
    final axis = stroke(colors.leader, line);
    for (var x = at(TopPose.butt).dx; x < at(TopPose.ball).dx; x += h * 0.14) {
      canvas.drawLine(Offset(x, h * 0.5), Offset(x + h * 0.07, h * 0.5), axis);
    }

    // Pieds : deux ovales dans le sens du regard (le gauche, éloigné, plus
    // clair).
    for (final (foot, color) in [
      (TopPose.leftFoot, far),
      (TopPose.rightFoot, colors.body),
    ]) {
      final rect = Rect.fromCenter(
        center: at(foot),
        width: h * 0.3,
        height: h * 0.13,
      );
      canvas
        ..drawOval(rect, Paint()..color = color)
        ..drawOval(rect, stroke(colors.stroke, line));
    }
    // Jambes : des hanches aux pieds.
    limb(at(TopPose.leftHip), at(TopPose.leftFoot), h * 0.07, color: far);
    limb(at(TopPose.rightHip), at(TopPose.rightFoot), h * 0.07);
    // Tronc : le quadrilatère hanches - épaules.
    final trunk = Path()
      ..moveTo(at(TopPose.rightHip).dx, at(TopPose.rightHip).dy)
      ..lineTo(at(TopPose.leftHip).dx, at(TopPose.leftHip).dy)
      ..lineTo(at(TopPose.leftShoulder).dx, at(TopPose.leftShoulder).dy)
      ..lineTo(at(TopPose.rightShoulder).dx, at(TopPose.rightShoulder).dy)
      ..close();
    canvas
      ..drawPath(trunk, Paint()..color = colors.body)
      ..drawPath(trunk, stroke(colors.stroke, line));
    // Bras : le gauche (éloigné) vers la main de chevalet, le droit vers la
    // main arrière.
    limb(at(TopPose.leftShoulder), at(TopPose.bridge), h * 0.065, color: far);
    limb(at(TopPose.rightShoulder), at(TopPose.backHand), h * 0.065);

    // Queue, du talon à la blanche, par-dessus les bras.
    final buttPoint = at(TopPose.butt);
    final tipPoint = at(TopPose.ball).translate(-h * 0.08, 0);
    limb(buttPoint, tipPoint, h * 0.035, color: colors.table.cueWood);

    // Mains.
    for (final hand in [TopPose.backHand, TopPose.bridge]) {
      canvas
        ..drawCircle(at(hand), h * 0.07, Paint()..color = colors.body)
        ..drawCircle(at(hand), h * 0.07, stroke(colors.stroke, line));
    }
    paintBilliardBall(
      canvas,
      center: at(TopPose.ball),
      radius: h * 0.075,
      fill: colors.balls.white,
      balls: colors.balls,
      table: colors.table,
    );

    // Tête (disque, sans visage) et ses deux yeux.
    canvas
      ..drawCircle(at(head), h * 0.12, Paint()..color = colors.body)
      ..drawCircle(at(head), h * 0.12, stroke(colors.stroke, line));
    for (final which in LeadEye.values) {
      final eye = at(TopPose.eye(which, headCase));
      if (which == leadEye) {
        // Œil directeur : une cible fixe.
        canvas
          ..drawCircle(eye, h * 0.04, Paint()..color = colors.balls.white)
          ..drawCircle(eye, h * 0.04, stroke(colors.stroke, line))
          ..drawCircle(eye, h * 0.018, Paint()..color = colors.target);
      } else {
        canvas
          ..drawCircle(eye, h * 0.03, Paint()..color = colors.balls.white)
          ..drawCircle(eye, h * 0.03, stroke(colors.stroke, line * 0.8));
      }
    }

    // Traits de renvoi des pastilles.
    for (final mark in TopPose.visibleMarks) {
      if (!focus.contains(mark)) continue;
      final target = TopPose.targetOf(mark, headCase);
      canvas
        ..drawLine(
          at(TopPose.badgeOf(mark)),
          at(target),
          stroke(colors.leader, line),
        )
        ..drawCircle(at(target), line * 1.1, Paint()..color = colors.stroke);
    }
  }

  @override
  bool shouldRepaint(_TopPainter old) =>
      old.focus != focus ||
      old.leadEye != leadEye ||
      old.headCase != headCase ||
      old.bridge != bridge ||
      old.colors != colors;
}
