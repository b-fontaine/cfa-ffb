import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/ghost_ball_geometry.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart' as geometry;
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Visée à la bille fantôme : la table avec la blanche, la bille de couleur,
/// la poche visée, la ligne de visée de la blanche vers la bille fantôme (trait
/// et point) et la bille fantôme elle-même, **calculée** (`G = O - s · unit(P
/// - O)` avec `s = r_c + r_o`, voir `ghostBallPosition`), dessinée au rayon de
/// la blanche. Le point de contact `O - r_o · unit(P - O)` est marqué.
///
/// [fraction] est la quantité de bille annoncée : elle nomme l'illustration
/// pour les lecteurs d'écran ; la cohérence avec la géométrie est contrôlée
/// par le test de contrat des séances (règle V17), pas ici.
///
/// À l'échelle de la table, le recouvrement des deux billes ne se lit pas :
/// sous la table, une **loupe** ([showInset]) agrandit le contact (bille de
/// couleur, bille fantôme, point de contact, ligne de visée, départ vers la
/// poche) et écrit son grossissement par rapport à la table.
class GhostAimDiagram extends StatelessWidget {
  const GhostAimDiagram({
    required this.cue,
    required this.object,
    required this.pocket,
    required this.fraction,
    this.showInset = true,
    super.key,
  });

  /// Loupe sur le contact sous la table.
  final bool showInset;

  /// Diamètre de la loupe, en part de la largeur de la table.
  static const double insetShare = 0.42;

  /// Diamètre minimal de la loupe, en pixels.
  static const double _minInsetDiameter = 64;

  /// Hauteur réservée au texte du grossissement.
  static const double _captionHeight = 24;

  /// Côté (cases) du champ de la loupe : deux fois `s`, la distance des
  /// centres au contact (les deux billes et une marge d'environ un rayon de
  /// chaque côté).
  static double get insetFieldCases => 2 * BallSizes.standard.ghostDistance;

  /// Centre de la blanche, dans le repère de la table (cases).
  final DiagramPoint cue;

  /// Centre de la bille de couleur.
  final DiagramPoint object;

  /// Poche visée.
  final geometry.TablePocket pocket;

  /// Quantité de bille annoncée.
  final ContactFraction fraction;

  /// Schéma de la visée : billes, bille fantôme, ligne de visée, trajectoire
  /// vers la poche et nom de la bille fantôme ([ghostName], déjà localisé).
  static TableDiagramSpec buildSpec({
    required DiagramPoint cue,
    required DiagramPoint object,
    required geometry.TablePocket pocket,
    required String ghostName,
  }) {
    final ghost = ghostBallPosition(object: object, pocket: pocket);
    final contact = contactPoint(object: object, pocket: pocket);
    return TableDiagramSpec(
      id: 'ghost-aim',
      balls: [
        DiagramBall(
          id: 'cue',
          color: BallKind.white,
          at: cue,
          role: DiagramBallRole.cue,
        ),
        DiagramBall(
          id: 'object',
          color: BallKind.red,
          at: object,
          role: DiagramBallRole.object,
        ),
      ],
      ghosts: [
        DiagramGhost(
          id: 'ghost',
          at: ghost,
          role: DiagramGhostRole.impact,
          forBallId: 'object',
        ),
        if (contact != null)
          DiagramGhost(
            id: 'contact',
            at: contact,
            role: DiagramGhostRole.contact,
            forBallId: 'object',
          ),
      ],
      arrows: [
        DiagramArrow(
          id: 'aim',
          kind: DiagramArrowKind.aim,
          path: [cue, ghost],
          ballId: 'cue',
        ),
        DiagramArrow(
          id: 'to-pocket',
          kind: DiagramArrowKind.object,
          path: [object, pocket.point],
          ballId: 'object',
          pocket: DiagramPocket.values.byName(pocket.name),
        ),
      ],
      annotations: [DiagramAnnotation(id: 'ghost', at: ghost, text: ghostName)],
    );
  }

  static String _pocketName(AppLocalizations l10n, geometry.TablePocket p) =>
      switch (p) {
        geometry.TablePocket.tl => l10n.pocketTopLeft,
        geometry.TablePocket.tm => l10n.pocketTopMiddle,
        geometry.TablePocket.tr => l10n.pocketTopRight,
        geometry.TablePocket.bl => l10n.pocketBottomLeft,
        geometry.TablePocket.bm => l10n.pocketBottomMiddle,
        geometry.TablePocket.br => l10n.pocketBottomRight,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.ghostAimLabel(
      BallContactDiagram.contactLabel(l10n, fraction),
      _pocketName(l10n, pocket),
    );
    final spec = buildSpec(
      cue: cue,
      object: object,
      pocket: pocket,
      ghostName: l10n.ghostBallName,
    );
    if (!showInset) {
      return TableDiagram(
        spec: spec,
        semanticLabel: label,
        showHeadString: false,
      );
    }
    return Semantics(
      label: '$label ${l10n.ghostAimInsetLabel}',
      container: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          var width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 360.0;
          var diameter = width * insetShare;
          // Hauteur bornée (test, écran court) : la loupe se réduit, puis la
          // table, pour que l'ensemble tienne sans déborder.
          if (constraints.hasBoundedHeight) {
            final maxHeight = constraints.maxHeight;
            const fixed = AppSpacing.sm + AppSpacing.xs + _captionHeight;
            var tableHeight = width / BilliardTable.aspect;
            if (tableHeight + fixed + diameter > maxHeight) {
              diameter = math.max(
                _minInsetDiameter,
                maxHeight - fixed - tableHeight,
              );
            }
            if (tableHeight + fixed + diameter > maxHeight) {
              tableHeight = math.max(0, maxHeight - fixed - diameter);
              width = tableHeight * BilliardTable.aspect;
            }
          }
          final tableUnit = TableGeometry.fitting(
            Size(width, width / BilliardTable.aspect),
          ).unit;
          final zoom = tableUnit == 0
              ? 1
              : (diameter / insetFieldCases / tableUnit).round();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                child: TableDiagram(
                  spec: spec,
                  semanticLabel: label,
                  showHeadString: false,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ContactInset(
                key: const ValueKey('ghost-aim-inset'),
                diameter: diameter,
                cue: cue,
                object: object,
                pocket: pocket,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.ghostAimInsetCaption(math.max(1, zoom)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Loupe : le contact entre la bille fantôme et la bille de couleur, agrandi.
class _ContactInset extends StatelessWidget {
  const _ContactInset({
    required this.diameter,
    required this.cue,
    required this.object,
    required this.pocket,
    super.key,
  });

  final double diameter;
  final DiagramPoint cue;
  final DiagramPoint object;
  final geometry.TablePocket pocket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _InsetPainter(
          cue: cue,
          object: object,
          pocket: pocket,
          balls: theme.extension<BallColors>() ?? BallColors.light,
          table: theme.extension<TableColors>() ?? TableColors.light,
          ink: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _InsetPainter extends CustomPainter {
  const _InsetPainter({
    required this.cue,
    required this.object,
    required this.pocket,
    required this.balls,
    required this.table,
    required this.ink,
  });

  final DiagramPoint cue;
  final DiagramPoint object;
  final geometry.TablePocket pocket;
  final BallColors balls;
  final TableColors table;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const sizes = BallSizes.standard;
    final ghost = ghostBallPosition(object: object, pocket: pocket);
    final contact = contactPoint(object: object, pocket: pocket);
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    // Champ de la loupe centré entre la bille fantôme et la bille de couleur.
    final mid = Offset((ghost.x + object.x) / 2, (ghost.y + object.y) / 2);
    final scale = size.shortestSide / GhostAimDiagram.insetFieldCases;
    Offset px(num x, num y) => centre + Offset(x - mid.dx, y - mid.dy) * scale;

    canvas
      ..save()
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
      )
      ..drawCircle(centre, radius, Paint()..color = balls.cloth);
    final line = Paint()
      ..color = table.headString
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Ligne de visée : de la blanche vers le centre de la bille fantôme.
    final aimFrom = px(cue.x, cue.y);
    final aimTo = px(ghost.x, ghost.y);
    final aimDir = (aimTo - aimFrom) / (aimTo - aimFrom).distance;
    for (var d = 0.0; d < radius * 2.5; d += 14) {
      canvas.drawLine(aimTo - aimDir * (d + 7), aimTo - aimDir * d, line);
    }
    // Départ de la bille de couleur vers la poche.
    final to = pocket.point;
    final objPx = px(object.x, object.y);
    final dir = px(to.x, to.y) - objPx;
    final unit = dir / dir.distance;
    final objectRadius = sizes.objectRadius * scale;
    canvas.drawLine(
      objPx + unit * objectRadius,
      objPx + unit * (objectRadius * 2.2),
      line,
    );
    paintBilliardBall(
      canvas,
      center: objPx,
      radius: objectRadius,
      fill: balls.red,
      balls: balls,
      table: table,
    );
    // Bille fantôme : cercle creux au rayon de la blanche.
    canvas.drawCircle(
      aimTo,
      sizes.cueRadius * scale,
      Paint()
        ..color = balls.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    if (contact != null) {
      canvas.drawCircle(
        px(contact.x, contact.y),
        math.max(4, scale * 0.012),
        Paint()..color = table.chalk,
      );
    }
    canvas
      ..restore()
      ..drawCircle(
        centre,
        radius - 1.5,
        Paint()
          ..color = ink
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      old.cue != cue ||
      old.object != object ||
      old.pocket != pocket ||
      old.balls != balls ||
      old.table != table ||
      old.ink != ink;
}
