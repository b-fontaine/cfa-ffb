import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/cue_side_geometry.dart';
import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Contact de deux billes inégales, vue de côté : la blanche (48,0 mm) et une
/// bille de but (50,8 mm) posées sur le tapis se touchent **légèrement
/// au-dessus de l'équateur de la blanche** (fiche n° 4 `[S]` : « légèrement
/// au-dessus de l'axe horizontal »).
///
/// En réalité la ligne des centres n'est inclinée que de 1,62° (0,68 mm
/// au-dessus de l'équateur) : invisible. Le dessin **exagère l'inclinaison
/// [exaggeration] fois** (16,24°) et le dit dans la légende comme dans la
/// description parlée : ce n'est jamais présenté comme une mesure.
class ContactHeightView extends StatelessWidget {
  const ContactHeightView({super.key});

  /// Facteur d'exagération de l'inclinaison de la ligne des centres.
  static const double exaggeration = 10;

  /// Rapport largeur / hauteur de la scène.
  static const double _aspect = 2.4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final format = NumberFormat(
      '0.0',
      Localizations.localeOf(context).toString(),
    );
    final heightFormat = NumberFormat(
      '0.00',
      Localizations.localeOf(context).toString(),
    );
    final note = l10n.contactHeightNote(
      format.format(BlackballDimensions.cueBallDiameterMm),
      format.format(BlackballDimensions.objectBallDiameterMm),
      heightFormat.format(BlackballDimensions.contactHeightAboveCueEquatorMm),
    );
    final style = theme.textTheme.bodyLarge;
    return Semantics(
      label: '${l10n.contactHeightLabel} $note',
      container: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: _aspect,
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _Scene(size: constraints.biggest),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _LegendItem(
                swatch: _Swatch.dashedLine,
                text: l10n.contactHeightEquatorLegend,
                style: style,
              ),
              _LegendItem(
                swatch: _Swatch.dot,
                text: l10n.contactHeightContactLegend,
                style: style,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(note, textAlign: TextAlign.center, style: style),
        ],
      ),
    );
  }
}

/// Rayon du repère du point de contact, en pixels.
const double _markerRadius = 6;

/// Épaisseur de l'équateur, en pixels (traits >= 3 px).
const double _strokeWidth = 3;

class _Scene extends StatelessWidget {
  const _Scene({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final w = size.width;
    final h = size.height;
    final diameter = h * 0.42;
    final radius = diameter / 2;
    final clothTop = h * 0.9;

    // Billes posées sur le même tapis ; rayon de la bille de but déduit de
    // l'inclinaison exagérée de la ligne des centres.
    const cueMm = BlackballDimensions.cueBallDiameterMm / 2;
    const objectMm = BlackballDimensions.objectBallDiameterMm / 2;
    final objectRadius =
        radius *
        exaggeratedObjectRadius(
          cueRadius: cueMm,
          objectRadius: objectMm,
          factor: ContactHeightView.exaggeration,
        ) /
        cueMm;
    final centresDistance = 2 * math.sqrt(radius * objectRadius);
    final cueCentre = Offset(w / 2 - centresDistance / 2, clothTop - radius);
    final objectCentre = Offset(
      w / 2 + centresDistance / 2,
      clothTop - objectRadius,
    );
    final tilt = contactHeight(
      cueRadius: radius,
      objectRadius: objectRadius,
    ).tilt;
    final contact =
        cueCentre + Offset(radius * math.cos(tilt), -radius * math.sin(tilt));

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _PlatePainter(
              clothTop: clothTop,
              plate: theme.colorScheme.surfaceContainerHighest,
              cloth: balls.cloth,
            ),
          ),
        ),
        Positioned(
          left: cueCentre.dx - radius,
          top: cueCentre.dy - radius,
          width: diameter,
          height: diameter,
          child: BilliardBall(kind: BallKind.white, diameter: diameter),
        ),
        Positioned(
          left: objectCentre.dx - objectRadius,
          top: objectCentre.dy - objectRadius,
          width: objectRadius * 2,
          height: objectRadius * 2,
          child: BilliardBall(kind: BallKind.red, diameter: objectRadius * 2),
        ),
        // Équateur de la blanche, peint par-dessus les billes : c'est lui qui
        // montre que le contact est au-dessus de l'axe horizontal.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('contact-height-equator'),
              painter: _EquatorPainter(
                from: Offset(cueCentre.dx - radius * 1.25, cueCentre.dy),
                to: Offset(contact.dx + radius * 0.6, cueCentre.dy),
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        Positioned(
          key: const ValueKey('contact-height-contact'),
          left: contact.dx - _markerRadius,
          top: contact.dy - _markerRadius,
          width: _markerRadius * 2,
          height: _markerRadius * 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: table.chalk,
              border: Border.all(
                color: theme.colorScheme.onSurface,
                width: _strokeWidth,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({
    required this.clothTop,
    required this.plate,
    required this.cloth,
  });

  final double clothTop;
  final Color plate;
  final Color cloth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height * 0.06),
        ),
        Paint()..color = plate,
      )
      ..drawRect(
        Rect.fromLTRB(0, clothTop, size.width, size.height),
        Paint()..color = cloth,
      );
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.clothTop != clothTop || old.plate != plate || old.cloth != cloth;
}

/// Équateur de la blanche : trait horizontal pointillé.
class _EquatorPainter extends CustomPainter {
  const _EquatorPainter({
    required this.from,
    required this.to,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth;
    final length = (to - from).distance;
    const dash = 8.0;
    for (var d = 0.0; d < length; d += dash * 2) {
      final a = from + (to - from) * (d / length);
      final b = from + (to - from) * (math.min(d + dash, length) / length);
      canvas.drawLine(a, b, line);
    }
  }

  @override
  bool shouldRepaint(_EquatorPainter old) =>
      old.from != from || old.to != to || old.color != color;
}

enum _Swatch { dashedLine, dot }

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.swatch,
    required this.text,
    required this.style,
  });

  final _Swatch swatch;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final ink = theme.colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        switch (swatch) {
          _Swatch.dashedLine => SizedBox(
            width: 28,
            height: _strokeWidth,
            child: CustomPaint(
              painter: _EquatorPainter(
                from: Offset.zero,
                to: const Offset(28, 0),
                color: ink,
              ),
            ),
          ),
          _Swatch.dot => DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: table.chalk,
              border: Border.all(color: ink, width: _strokeWidth),
            ),
            child: const SizedBox(width: 16, height: 16),
          ),
        },
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
