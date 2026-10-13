import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Œil directeur du joueur droitier (voir la fiche technique n° 1).
enum StanceLeadEye { left, right }

/// Positions du schéma, en part de la largeur (`dx`) et de la hauteur (`dy`) :
/// le joueur regarde vers la droite, la queue suit l'axe `dy = 0,5`, la droite
/// du joueur est donc **en bas** du dessin. Schéma de joueur droitier, sans
/// silhouette.
abstract final class StanceLayout {
  /// Talon de la queue.
  static const Offset butt = Offset(0.06, 0.5);

  /// Centre de la blanche.
  static const Offset ball = Offset(0.94, 0.5);

  /// Tête (vue de dessus), sur l'axe de la queue.
  static const Offset head = Offset(0.6, 0.5);

  /// Main de chevalet, sur l'axe de la queue devant la tête.
  static const Offset bridge = Offset(0.8, 0.5);

  /// Pied droit, sous la main droite qui tient la queue.
  static const Offset rightFoot = Offset(0.34, 0.76);

  /// Pied gauche, devant et à gauche de l'axe.
  static const Offset leftFoot = Offset(0.5, 0.26);

  /// Hanche droite et hanche gauche (bassin légèrement pivoté).
  static const Offset rightHip = Offset(0.38, 0.6);
  static const Offset leftHip = Offset(0.44, 0.42);

  /// Écart des yeux à l'axe, en part de la hauteur.
  static const double eyeOffset = 0.045;

  /// Position d'un œil : à l'avant de la tête, de part et d'autre de l'axe.
  static Offset eye(StanceLeadEye which) => Offset(
    head.dx + 0.035,
    head.dy + (which == StanceLeadEye.right ? eyeOffset : -eyeOffset),
  );
}

/// Posture vue de dessus : pieds, hanches, queue, tête avec l'œil directeur et
/// main de chevalet. Schématique : traits et formes simples, pas de
/// silhouette.
///
/// Chaque partie est nommée à côté d'un trait de repère. Les [annotations]
/// (points d'attention de la séance, déjà en français) sont écrites sous le
/// schéma et lues après la description des parties.
class StanceDiagram extends StatelessWidget {
  const StanceDiagram({
    this.annotations = const [],
    this.leadEye = StanceLeadEye.right,
    super.key,
  });

  final List<String> annotations;
  final StanceLeadEye leadEye;

  /// Rapport largeur / hauteur du schéma.
  static const double _aspect = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final label = annotations.isEmpty
        ? l10n.stanceLabel
        : l10n.stanceLabelWithNotes(annotations.join(' ; '));
    return Semantics(
      label: label,
      container: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: _aspect,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                Offset at(Offset p) =>
                    Offset(p.dx * size.width, p.dy * size.height);
                final textStyle = theme.textTheme.labelSmall?.copyWith(
                  color: balls.onCloth,
                );
                final labels = <(Offset, String)>[
                  (const Offset(0.34, 0.93), l10n.stancePartFeet),
                  (const Offset(0.2, 0.66), l10n.stancePartHips),
                  (const Offset(0.16, 0.4), l10n.stancePartCue),
                  (const Offset(0.82, 0.76), l10n.stancePartBridge),
                  (const Offset(0.7, 0.2), l10n.stancePartEye),
                ];
                final cueLength =
                    (StanceLayout.ball.dx - 0.05) * size.width -
                    StanceLayout.butt.dx * size.width;
                final thickness = size.height * 0.05;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _StancePainter(
                          leadEye: leadEye,
                          balls: balls,
                          table: table,
                          labelAnchors: [for (final l in labels) l.$1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: at(StanceLayout.butt).dx,
                      top: at(StanceLayout.butt).dy - thickness / 2,
                      width: cueLength,
                      height: thickness,
                      child: BilliardCue(
                        length: cueLength,
                        thickness: thickness,
                      ),
                    ),
                    Positioned(
                      left: at(StanceLayout.ball).dx - size.height * 0.07,
                      top: at(StanceLayout.ball).dy - size.height * 0.07,
                      width: size.height * 0.14,
                      height: size.height * 0.14,
                      child: BilliardBall(
                        kind: BallKind.white,
                        diameter: size.height * 0.14,
                      ),
                    ),
                    for (final (anchor, text) in labels)
                      Positioned(
                        left: at(anchor).dx,
                        top: at(anchor).dy,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: Text(text, softWrap: false, style: textStyle),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          for (final note in annotations)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(note, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StancePainter extends CustomPainter {
  const _StancePainter({
    required this.leadEye,
    required this.balls,
    required this.table,
    required this.labelAnchors,
  });

  final StanceLeadEye leadEye;
  final BallColors balls;
  final TableColors table;

  /// Points des étiquettes, dans l'ordre pieds, hanches, queue, chevalet, œil.
  final List<Offset> labelAnchors;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = balls.onCloth;
    final fill = Paint()..color = balls.white;
    final leader = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = balls.onCloth.withValues(alpha: 0.6);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h * 0.06)),
      Paint()..color = balls.cloth,
    );
    // Axe de visée : de la queue à la blanche, en pointillés.
    final axis = at(StanceLayout.butt);
    final end = at(StanceLayout.ball);
    for (var x = axis.dx; x < end.dx; x += h * 0.09) {
      canvas.drawLine(
        Offset(x, axis.dy),
        Offset(x + h * 0.04, axis.dy),
        leader,
      );
    }

    // Bassin : une barre épaisse entre les deux hanches.
    final hips = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.09
      ..color = balls.white;
    canvas
      ..drawLine(at(StanceLayout.rightHip), at(StanceLayout.leftHip), hips)
      ..drawLine(
        at(StanceLayout.rightHip),
        at(StanceLayout.leftHip),
        stroke..strokeWidth = 2,
      );

    // Pieds : deux ovales orientés dans le sens du regard.
    for (final foot in [StanceLayout.rightFoot, StanceLayout.leftFoot]) {
      final rect = Rect.fromCenter(
        center: at(foot),
        width: h * 0.2,
        height: h * 0.09,
      );
      canvas
        ..drawOval(rect, fill)
        ..drawOval(rect, stroke);
    }

    // Tête, vue de dessus, et les deux yeux.
    canvas
      ..drawCircle(
        at(StanceLayout.head),
        h * 0.1,
        Paint()..color = table.cueFerrule,
      )
      ..drawCircle(at(StanceLayout.head), h * 0.1, stroke);
    for (final which in StanceLeadEye.values) {
      final centre = at(StanceLayout.eye(which));
      if (which == leadEye) {
        canvas
          ..drawCircle(centre, h * 0.035, Paint()..color = table.chalk)
          ..drawCircle(centre, h * 0.05, stroke);
      } else {
        canvas.drawCircle(centre, h * 0.025, stroke);
      }
    }

    // Main de chevalet : un disque posé sur l'axe, devant la tête.
    canvas
      ..drawCircle(at(StanceLayout.bridge), h * 0.06, fill)
      ..drawCircle(at(StanceLayout.bridge), h * 0.06, stroke);

    // Traits de repère des étiquettes (pieds, hanches, queue, chevalet, œil).
    final targets = <Offset>[
      at(StanceLayout.rightFoot),
      at(StanceLayout.rightHip),
      Offset(labelAnchors[2].dx * size.width, at(StanceLayout.butt).dy),
      at(StanceLayout.bridge),
      at(StanceLayout.eye(leadEye)),
    ];
    for (var i = 0; i < targets.length; i++) {
      canvas.drawLine(at(labelAnchors[i]), targets[i], leader);
    }
  }

  @override
  bool shouldRepaint(_StancePainter old) =>
      old.leadEye != leadEye ||
      old.balls != balls ||
      old.table != table ||
      old.labelAnchors != labelAnchors;
}
