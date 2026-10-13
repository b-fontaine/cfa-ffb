import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Géométrie du plan amplitude × vitesse : l'amplitude (recul de la main) en
/// abscisse, la vitesse en ordonnée (vers le haut), toutes deux de 0 à 1.
///
/// Les zones sont les régions du produit `amplitude × vitesse` : les limites
/// sont donc des hyperboles, ce qui montre un **rapport** entre les deux
/// grandeurs et non des paliers.
class PowerPlaneGeometry {
  const PowerPlaneGeometry(this.size);

  /// Taille du plan, en pixels.
  final Size size;

  /// Position d'un point du plan : (0 ; 0) en bas à gauche, (1 ; 1) en haut à
  /// droite.
  Offset position(double amplitude, double speed) =>
      Offset(amplitude * size.width, (1 - speed) * size.height);

  /// Position d'un exemple.
  Offset positionOf(AmplitudeLevel amplitude, SpeedLevel speed) =>
      position(amplitude.value, speed.value);

  /// Vitesse (de 0 à 1) où le produit vaut [limit] à l'amplitude donnée, ou
  /// `null` au-delà de 1 (la limite n'est pas atteinte).
  double? speedAtLimit(double limit, double amplitude) {
    final speed = limit / amplitude;
    return speed > 1 ? null : speed;
  }
}

/// Plan « amplitude × vitesse » : trois zones (doux, moyen, puissant) et des
/// exemples placés, dont l'un peut être mis en évidence.
///
/// Source `[S]` : fiche technique n° 2, « la puissance dépend de deux
/// critères, la vitesse et l'amplitude ». Les zones se distinguent par un
/// motif (aucun, hachures, croisillons) et par leur nom écrit dans la zone,
/// jamais par la couleur seule. Chaque exemple est écrit sous le plan avec sa
/// zone atteinte.
class PowerRatio extends StatelessWidget {
  const PowerRatio({
    this.points = const [],
    this.highlight,
    this.distanceLabel,
    super.key,
  });

  /// Exemples placés ; vide : le plan seul.
  final List<PowerPoint> points;

  /// Indice de l'exemple mis en évidence ; hors de [points], aucun exemple
  /// n'est mis en évidence.
  final int? highlight;

  int? get _marked =>
      highlight != null && highlight! >= 0 && highlight! < points.length
      ? highlight
      : null;

  /// Texte de repère de la séance (déjà en français), écrit sous le plan.
  final String? distanceLabel;

  static String amplitudeName(AppLocalizations l10n, AmplitudeLevel a) =>
      switch (a) {
        AmplitudeLevel.short => l10n.amplitudeShort,
        AmplitudeLevel.medium => l10n.amplitudeMedium,
        AmplitudeLevel.long => l10n.amplitudeLong,
      };

  static String speedName(AppLocalizations l10n, SpeedLevel s) => switch (s) {
    SpeedLevel.slow => l10n.speedSlow,
    SpeedLevel.medium => l10n.speedMedium,
    SpeedLevel.fast => l10n.speedFast,
  };

  static String zoneName(AppLocalizations l10n, PowerZone z) => switch (z) {
    PowerZone.soft => l10n.powerZoneSoft,
    PowerZone.medium => l10n.powerZoneMedium,
    PowerZone.strong => l10n.powerZoneStrong,
  };

  /// Texte d'un exemple : amplitude, vitesse et zone atteinte.
  static String pointText(AppLocalizations l10n, PowerPoint point) {
    final amplitude = amplitudeName(l10n, point.amplitude);
    final speed = speedName(l10n, point.speed);
    final zone = zoneName(l10n, point.zone);
    final label = point.label;
    return label == null
        ? l10n.powerRatioPoint(amplitude, speed, zone)
        : l10n.powerRatioPointWithLabel(label, amplitude, speed, zone);
  }

  /// Marge autour du plan : les repères des extrémités y débordent.
  static const double _padding = 18;

  /// Largeur maximale de l'illustration (plan et légendes), en pixels.
  static const double _maxWidth = 420;

  /// Rapport largeur / hauteur du plan.
  static const double _aspect = 1.2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final textStyle = theme.textTheme.bodyMedium;
    final labelStyle = theme.textTheme.labelLarge;

    final lines = [
      for (final (i, p) in points.indexed)
        if (points.length > 1)
          '${i + 1}. ${pointText(l10n, p)}'
        else
          pointText(l10n, p),
    ];
    final spoken = [
      if (points.isEmpty) l10n.powerRatioEmptyLabel else ...lines,
      if (_marked != null) l10n.powerRatioHighlightNote('${_marked! + 1}'),
      ?distanceLabel,
    ];

    return Semantics(
      label: spoken.join('. '),
      container: true,
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.powerRatioAxisSpeed, style: labelStyle),
              const SizedBox(height: AppSpacing.xs),
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: constraints.maxWidth / _aspect,
                  child: _Plane(
                    points: points,
                    highlight: _marked,
                    padding: _padding,
                  ),
                ),
              ),
              Text(
                l10n.powerRatioAxisAmplitude,
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
              if (lines.isNotEmpty) const SizedBox(height: AppSpacing.sm),
              for (final (i, line) in lines.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    line,
                    style: i == _marked
                        ? textStyle?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          )
                        : textStyle,
                  ),
                ),
              if (distanceLabel != null) Text(distanceLabel!, style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _Plane extends StatelessWidget {
  const _Plane({
    required this.points,
    required this.highlight,
    required this.padding,
  });

  final List<PowerPoint> points;
  final int? highlight;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final zoneStyle = theme.textTheme.labelLarge;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inner = Size(
          math.max(1, constraints.maxWidth - 2 * padding),
          math.max(1, constraints.maxHeight - 2 * padding),
        );
        final plane = PowerPlaneGeometry(inner);
        Widget zone(String text, double a, double v) {
          final at = plane.position(a, v);
          return Positioned(
            left: padding + at.dx,
            top: padding + at.dy,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.85),
                  borderRadius: AppRadii.smallRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(text, softWrap: false, style: zoneStyle),
                ),
              ),
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PlanePainter(
                  plane: plane,
                  padding: padding,
                  points: points,
                  scheme: scheme,
                ),
              ),
            ),
            // Positions des noms : un point de chaque zone du produit.
            zone(l10n.powerZoneSoft, 0.13, 0.13),
            // À l'écart des neuf positions d'exemple (0,3 / 0,6 / 1) : produit 0,36.
            zone(l10n.powerZoneMedium, 0.8, 0.45),
            zone(l10n.powerZoneStrong, 0.84, 0.86),
            for (final (i, p) in points.indexed)
              Builder(
                builder: (context) {
                  final at = plane.positionOf(p.amplitude, p.speed);
                  final selected = i == highlight;
                  final size = selected ? 34.0 : 28.0;
                  return Positioned(
                    left: padding + at.dx - size / 2,
                    top: padding + at.dy - size / 2,
                    width: size,
                    height: size,
                    child: _PointMarker(
                      key: ValueKey('power-point-$i'),
                      number: points.length > 1 ? i + 1 : null,
                      selected: selected,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _PointMarker extends StatelessWidget {
  const _PointMarker({required this.number, required this.selected, super.key});

  final int? number;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary,
        border: Border.all(color: scheme.onSurface, width: selected ? 4 : 3),
      ),
      child: Center(
        child: selected
            ? Icon(
                Icons.check,
                key: const ValueKey('power-highlight'),
                size: 20,
                color: on,
              )
            : number == null
            ? null
            : MediaQuery.withNoTextScaling(
                child: Text(
                  '$number',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: on),
                ),
              ),
      ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  const _PlanePainter({
    required this.plane,
    required this.padding,
    required this.points,
    required this.scheme,
  });

  final PowerPlaneGeometry plane;
  final double padding;
  final List<PowerPoint> points;
  final ColorScheme scheme;

  /// Points de la courbe `amplitude × vitesse = limit`, de a = limit à 1.
  List<Offset> _curve(double limit) {
    const steps = 24;
    return [
      for (var i = 0; i <= steps; i++)
        () {
          final a = limit + (1 - limit) * i / steps;
          return plane.position(a, limit / a);
        }(),
    ];
  }

  Path _path(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(padding, padding);
    final w = plane.size.width;
    final h = plane.size.height;
    const soft = powerSoftLimit;
    const strong = powerStrongLimit;
    final low = _curve(soft); // de (0,2 ; 1) à (1 ; 0,2)
    final high = _curve(strong); // de (0,5 ; 1) à (1 ; 0,5)

    // Doux : du bas du plan à la courbe 0,2, sur toute la bande gauche.
    final softZone = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w, low.last.dy);
    for (final p in low.reversed.skip(1)) {
      softZone.lineTo(p.dx, p.dy);
    }
    softZone
      ..lineTo(0, 0)
      ..close();

    // Moyen : entre les courbes 0,2 et 0,5.
    final mediumZone = Path()..moveTo(high.first.dx, high.first.dy);
    for (final p in high.skip(1)) {
      mediumZone.lineTo(p.dx, p.dy);
    }
    for (final p in low.reversed) {
      mediumZone.lineTo(p.dx, p.dy);
    }
    mediumZone.close();

    // Puissant : au-delà de la courbe 0,5, jusqu'au coin haut droit.
    final strongZone = Path()..moveTo(high.first.dx, high.first.dy);
    for (final p in high.skip(1)) {
      strongZone.lineTo(p.dx, p.dy);
    }
    strongZone
      ..lineTo(w, 0)
      ..lineTo(high.first.dx, 0)
      ..close();

    final tint = scheme.primary;
    canvas
      ..drawPath(softZone, Paint()..color = tint.withValues(alpha: 0.08))
      ..drawPath(mediumZone, Paint()..color = tint.withValues(alpha: 0.2))
      ..drawPath(strongZone, Paint()..color = tint.withValues(alpha: 0.36));

    // Motifs : hachures pour « moyen », croisillons pour « puissant ».
    final hatch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = tint.withValues(alpha: 0.45);
    void hatchZone(Path zone, {required bool cross}) {
      canvas
        ..save()
        ..clipPath(zone);
      const gap = 18.0;
      for (var x = -h; x < w + h; x += gap) {
        canvas.drawLine(Offset(x, h), Offset(x + h, 0), hatch);
        if (cross) canvas.drawLine(Offset(x, 0), Offset(x + h, h), hatch);
      }
      canvas.restore();
    }

    hatchZone(mediumZone, cross: false);
    hatchZone(strongZone, cross: true);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = scheme.onSurfaceVariant;
    canvas
      ..drawPath(_path(low), border)
      ..drawPath(_path(high), border);

    // Axes avec flèche : la grandeur croît vers le haut et vers la droite.
    final axis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = scheme.onSurface;
    const head = 9.0;
    canvas
      ..drawLine(Offset(0, h), Offset(w, h), axis)
      ..drawLine(Offset(w, h), Offset(w - head, h - head / 2), axis)
      ..drawLine(Offset(w, h), Offset(w - head, h + head / 2), axis)
      ..drawLine(Offset(0, h), Offset.zero, axis)
      ..drawLine(Offset.zero, const Offset(head / 2, head), axis)
      ..drawLine(Offset.zero, const Offset(-head / 2, head), axis);

    // Traits de repère de chaque exemple vers les deux axes.
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = scheme.onSurface;
    for (final p in points) {
      final at = plane.positionOf(p.amplitude, p.speed);
      _dashed(canvas, at, Offset(0, at.dy), guide);
      _dashed(canvas, at, Offset(at.dx, h), guide);
    }
    canvas.restore();
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    final length = (to - from).distance;
    if (length == 0) return;
    final unit = (to - from) / length;
    const dash = 7.0;
    for (var d = 0.0; d < length; d += dash * 2) {
      canvas.drawLine(
        from + unit * d,
        from + unit * math.min(d + dash, length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PlanePainter old) =>
      old.plane.size != plane.size ||
      old.padding != padding ||
      old.points != points ||
      old.scheme != scheme;
}
