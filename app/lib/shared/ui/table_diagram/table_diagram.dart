import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/table_diagram/diagram_timeline.dart';
import 'package:billard_cfa/shared/ui/table_diagram/label_placement.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Schéma d'exercice : table, billes, cercles creux, flèches et zones.
///
/// Sans [frame], le schéma montre l'état initial de [spec] (avec la queue
/// pointée sur la cible si un tir est décrit). Avec une [frame] issue de
/// `DiagramTimeline`, il montre les billes à cet instant ; les billes
/// empochées ne sont plus dessinées.
///
/// [semanticLabel] décrit l'exercice (texte localisé fourni par l'appelant).
/// Sur une table réduite, la bille est trop petite pour porter sa lettre : la
/// lettre (R/J/N/B) est alors écrite à côté, avec le repère éventuel (« x4 »).
/// Les flèches se distinguent par leur trait (plein : bille touchée ; tirets :
/// blanche ; points : indication), pas par la couleur.
class TableDiagram extends StatelessWidget {
  const TableDiagram({
    required this.spec,
    required this.semanticLabel,
    this.frame,
    this.showGrid = true,
    this.showHeadString = true,
    super.key,
  });

  final TableDiagramSpec spec;

  /// Description de l'exercice pour les lecteurs d'écran.
  final String semanticLabel;

  /// État à afficher ; l'état initial de [spec] si absent.
  final DiagramFrame? frame;

  final bool showGrid;
  final bool showHeadString;

  /// Diamètre (px) à partir duquel la lettre tient dans la bille.
  static const double _letterInside = 28;

  /// Marge (px) autour du texte d'une étiquette : sert de halo si besoin.
  static const double _haloPadding = 2;

  /// Largeurs maximales d'une étiquette, en part de la largeur de la surface :
  /// au-delà, le texte passe à la ligne. La première est la préférée ; les
  /// suivantes, plus étroites, sont essayées quand la table est trop chargée.
  static const _labelWidthShares = [0.4, 0.25, 0.15];

  /// Taille minimale (px logiques, texte agrandi compris) d'une étiquette sous
  /// un `PresentationScope` : lisible au fond d'une salle.
  static const double presentationMinLabel = 16;

  /// Rayon (px) réservé autour du point d'une annotation pour que le médaillon
  /// ne la recouvre pas.
  static const double _noteReserve = 12;

  /// Largeur du médaillon de quantité de bille, en part de la largeur de la
  /// surface de jeu.
  static const double _insetShare = 0.2;

  /// Tailles essayées pour le médaillon sur la table, en part de
  /// [_insetShare] : la pleine taille d'abord, puis réduite.
  static const _insetScales = [1.0, 0.75];

  /// Hauteur (px) minimale de la table sous une hauteur bornée, médaillon sous
  /// elle compris : en dessous, la table garde sa hauteur naturelle.
  static const double _minTableHeight = 40;

  /// Part de la largeur de la surface au-delà de laquelle le médaillon (dont le
  /// libellé ne se coupe pas) est trop large pour la table : il est écrit sous
  /// elle.
  static const double _insetMaxShare = 0.25;

  @override
  Widget build(BuildContext context) {
    final DiagramFrame current;
    try {
      current = frame ?? DiagramTimeline.of(spec).initialFrame;
    } on InvalidDiagramException {
      return ErrorView(message: AppLocalizations.of(context).diagramInvalid);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        TableGeometry geometryFor(double width) =>
            TableGeometry.fitting(Size(width, width / BilliardTable.aspect));
        var width = constraints.maxWidth;
        if (constraints.hasBoundedHeight) {
          width = math.min(width, constraints.maxHeight * BilliardTable.aspect);
        }
        var layout = _layout(context, geometryFor(width), current);
        var fits = true;
        if (layout.insetBelow != null && constraints.hasBoundedHeight) {
          // Sous une hauteur bornée, la table laisse sa place au médaillon ; en
          // rétrécissant, la table raccourcit mais le libellé du médaillon peut
          // passer à la ligne : on recalcule jusqu'à ce que l'ensemble tienne.
          // Faute de place pour une table lisible, la hauteur naturelle
          // l'emporte (la page défile).
          fits = false;
          for (var i = 0; i < 4; i++) {
            final below = layout.insetBelow;
            if (below == null) {
              fits = true;
              break;
            }
            final total =
                width / BilliardTable.aspect + AppSpacing.sm + below.height;
            if (total <= constraints.maxHeight + 0.01) {
              fits = true;
              break;
            }
            final room = constraints.maxHeight - below.height - AppSpacing.sm;
            if (room < _minTableHeight) break;
            width = math.min(width, room * BilliardTable.aspect);
            layout = _layout(context, geometryFor(width), current);
          }
          if (!fits) {
            width = constraints.maxWidth;
            layout = _layout(context, geometryFor(width), current);
          }
        }
        // Le médaillon sous la table est à côté de la description, pas dedans :
        // il porte sa propre description parlée.
        final table = Semantics(
          label: semanticLabel,
          container: true,
          child: BilliardTable(
            showGrid: showGrid,
            showHeadString: showHeadString,
            overlay: (context, geometry) =>
                _overlay(context, geometry, current, layout),
          ),
        );
        final legend = layout.insetBelow;
        final content = Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: SizedBox(
            width: width,
            child: legend == null
                ? table
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      table,
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _insetCard(
                          context,
                          legend.contact,
                          legend.tipPoint,
                          legend.width,
                        ),
                      ),
                    ],
                  ),
          ),
        );
        // Hors de la borne de hauteur : déborde sans erreur plutôt que de
        // s'écraser.
        return fits
            ? content
            : OverflowBox(
                maxHeight: double.infinity,
                alignment: Alignment.topCenter,
                child: content,
              );
      },
    );
  }

  /// Points en pixels du tracé de [arrow] : la pointe qui arrive sur un cercle
  /// creux s'arrête à son bord, pour que le cercle reste visible.
  @visibleForTesting
  static List<Offset> arrowPixelPoints(
    TableDiagramSpec spec,
    DiagramArrow arrow,
    TableGeometry geometry,
  ) {
    var points = [for (final p in arrow.path) geometry.toPixel(_offset(p))];
    for (final ghost in spec.ghosts) {
      if (ghost.role == DiagramGhostRole.contact) continue;
      points = retractTipToCircle(
        points,
        geometry.toPixel(_offset(ghost.at)),
        geometry.ghostRadiusPx,
      );
    }
    return points;
  }

  /// Rayon en pixels du point plein du point de contact (8,5 mm).
  static double _contactDotRadius(TableGeometry geometry) => math.max(
    2.5,
    BlackballDimensions.tipDiameterMm /
        2 /
        BlackballDimensions.cellMm *
        geometry.unit,
  );

  /// Style des étiquettes : `labelSmall`, agrandi sous un `PresentationScope`
  /// pour atteindre [presentationMinLabel] une fois le texte agrandi.
  TextStyle? _labelStyle(BuildContext context) {
    final theme = Theme.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final scaler = MediaQuery.textScalerOf(context);
    var textStyle = theme.textTheme.labelSmall?.copyWith(color: balls.onCloth);
    if (PresentationScope.isActive(context) && textStyle != null) {
      final size = textStyle.fontSize ?? 14;
      final shown = scaler.scale(size);
      if (shown > 0 && shown < presentationMinLabel) {
        textStyle = textStyle.copyWith(
          fontSize: size * presentationMinLabel / shown,
        );
      }
    }
    return textStyle;
  }

  Widget _overlay(
    BuildContext context,
    TableGeometry geometry,
    DiagramFrame current,
    _DiagramLayout layout,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final textStyle = _labelStyle(context);
    final initial = _initialFrame(current);
    final placement = layout.labels;
    final cue = _cueOf(current);
    final halo = balls.cloth.withValues(alpha: 0.85);

    Widget label(String key, String text, LabelPlacement place, Offset shift) =>
        Positioned(
          key: ValueKey(key),
          left: place.rect.left + shift.dx,
          top: place.rect.top + shift.dy,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: place.rect.width + 0.5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: place.crowded ? halo : null,
                borderRadius: BorderRadius.circular(_haloPadding * 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_haloPadding),
                child: Text(text, style: textStyle),
              ),
            ),
          ),
        );

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GuidePainter(
                spec: spec,
                geometry: geometry,
                ink: table.headString,
              ),
            ),
          ),
          for (final ghost in spec.ghosts)
            if (placement.insideGhosts.contains(ghost.id))
              Positioned.fromRect(
                key: ValueKey('ghost-mark-${ghost.id}'),
                rect: Rect.fromCircle(
                  center: geometry.toPixel(_offset(ghost.at)),
                  radius: geometry.ghostRadiusPx,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: halo,
                  ),
                  child: Center(
                    child: Text(
                      ghost.label!,
                      softWrap: false,
                      style: textStyle,
                    ),
                  ),
                ),
              )
            else if (placement.ghosts[ghost.id] case final place?)
              label(
                'ghost-label-${ghost.id}',
                ghost.label!,
                place,
                Offset.zero,
              ),
          for (final note in spec.annotations)
            if (placement.notes[note.id] case final place?)
              label('annotation-${note.id}', note.text, place, Offset.zero),
          if (cue != null)
            BilliardCue.positionedAgainst(
              geometry: geometry,
              ball: cue.ball,
              angle: cue.angle,
              touching: cue.kind,
            ),
          for (final ball in spec.balls)
            if (!(current.balls[ball.id]?.pocketed ?? false))
              Positioned.fromRect(
                key: ValueKey('ball-${ball.id}'),
                rect: geometry.ballRect(
                  _positionOf(current, ball),
                  _kind(ball.color),
                ),
                child: BilliardBall(
                  kind: _kind(ball.color),
                  diameter: geometry.radiusPxOf(_kind(ball.color)) * 2,
                  label: _label(
                    l10n,
                    ball,
                    geometry.radiusPxOf(_kind(ball.color)) * 2,
                  ),
                  outsideLabel: false,
                ),
              ),
          for (final ball in spec.balls)
            if (!(current.balls[ball.id]?.pocketed ?? false))
              if (placement.balls[ball.id] case final place?)
                label(
                  'ball-label-${ball.id}',
                  _label(
                    l10n,
                    ball,
                    geometry.radiusPxOf(_kind(ball.color)) * 2,
                  )!,
                  place,
                  geometry.toPixel(_positionOf(current, ball)) -
                      geometry.toPixel(_positionOf(initial, ball)),
                ),
          if (layout.insetOnTable case final rect?)
            Positioned.fromRect(
              rect: rect,
              child: _insetCard(
                context,
                spec.inset!.contact,
                spec.inset!.tipPoint,
                layout.insetWidth,
              ),
            ),
        ],
      ),
    );
  }

  /// État initial du schéma ([current] si la chronologie est invalide).
  DiagramFrame _initialFrame(DiagramFrame current) {
    try {
      return DiagramTimeline.of(spec).initialFrame;
    } on InvalidDiagramException {
      return current;
    }
  }

  /// Queue montrée à l'état [frame] : bille jouée, direction et couleur de la
  /// bille contre laquelle la pointe se pose ; `null` sans tir décrit.
  ({Offset ball, double angle, BallKind kind})? _cueOf(DiagramFrame frame) {
    final angle = frame.cueAngle;
    if (angle == null || frame.stepIndex < 0) return null;
    final id = spec.steps[frame.stepIndex].cueId;
    final position = frame.balls[id]?.position;
    if (position == null) return null;
    return (ball: _offset(position), angle: angle, kind: _colorOf(id));
  }

  /// Traits de la queue de l'état [frame] (axe et deux bords du talon), à ne
  /// pas recouvrir ; vide sans queue.
  List<List<Offset>> _cuePaths(TableGeometry geometry, DiagramFrame frame) {
    final cue = _cueOf(frame);
    if (cue == null) return const [];
    final layout = BilliardCue.layoutAgainst(
      geometry: geometry,
      ball: cue.ball,
      angle: cue.angle,
      touching: cue.kind,
    );
    final direction = Offset(math.cos(cue.angle), math.sin(cue.angle));
    final side = Offset(-direction.dy, direction.dx) * (layout.thickness / 2);
    final butt = layout.tip - direction * layout.length;
    return [
      for (final shift in [-side, Offset.zero, side])
        [butt + shift, layout.tip + shift],
    ];
  }

  /// Position de [ball] à l'état [frame] (celle du schéma à défaut).
  Offset _positionOf(DiagramFrame frame, DiagramBall ball) =>
      _offset(frame.balls[ball.id]?.position ?? ball.at);

  /// Disques à ne pas recouvrir : billes (à l'état [initial]), cercles creux,
  /// points de contact.
  List<LabelDisc> _discs(TableGeometry geometry, DiagramFrame initial) => [
    for (final ball in spec.balls)
      LabelDisc(
        geometry.toPixel(_positionOf(initial, ball)),
        geometry.radiusPxOf(_kind(ball.color)),
      ),
    for (final ghost in spec.ghosts)
      LabelDisc(
        geometry.toPixel(_offset(ghost.at)),
        ghost.role == DiagramGhostRole.contact
            ? _contactDotRadius(geometry)
            : geometry.ghostRadiusPx,
      ),
  ];

  /// Traits à ne pas recouvrir : flèches (pointe reculée au cercle) et queue.
  List<List<Offset>> _paths(TableGeometry geometry, DiagramFrame initial) => [
    for (final arrow in spec.arrows)
      if (arrow.path.length >= 2) arrowPixelPoints(spec, arrow, geometry),
    ..._cuePaths(geometry, initial),
  ];

  /// Étiquettes et médaillon de la quantité de bille, calculés sur l'état
  /// initial : ils ne dépendent que du schéma et de la table, pas de l'instant
  /// de l'animation.
  ///
  /// Le médaillon est posé en premier, sur la table, là où il ne recouvre ni
  /// trajectoire, ni bille, ni cercle, ni queue, ni point d'annotation ; les
  /// étiquettes l'évitent ensuite. Faute de place libre (ou si une étiquette ne
  /// peut l'éviter), il est écrit sous la table : jamais sur un objet.
  _DiagramLayout _layout(
    BuildContext context,
    TableGeometry geometry,
    DiagramFrame current,
  ) {
    final l10n = AppLocalizations.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final style = _labelStyle(context);
    final initial = _initialFrame(current);
    final inset = spec.inset;

    Rect? insetRect;
    var insetWidth = 0.0;
    TextPainter? caption;
    if (inset != null) {
      caption = TextPainter(
        text: TextSpan(
          text: BallContactDiagram.contactLabel(l10n, inset.contact),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final surfaceWidth = geometry.surface.width;
      // Le libellé ne se coupe pas : le médaillon est au moins aussi large.
      final natural = caption.width.ceilToDouble() + 1;
      insetWidth = math.max(surfaceWidth * _insetShare, natural);
      if (natural <= surfaceWidth * _insetMaxShare) {
        final paths = _paths(geometry, initial);
        final discs = [
          ..._discs(geometry, initial),
          for (final note in spec.annotations)
            LabelDisc(geometry.toPixel(_offset(note.at)), _noteReserve),
        ];
        for (final scale in _insetScales) {
          final width = math.max(surfaceWidth * _insetShare * scale, natural);
          insetRect = placeBlock(
            size: _insetSize(width, caption.height),
            bounds: geometry.surface,
            paths: paths,
            discs: discs,
          );
          if (insetRect != null) {
            insetWidth = width;
            break;
          }
        }
      }
    }

    var labels = _placeLabels(
      geometry: geometry,
      l10n: l10n,
      style: style,
      scaler: scaler,
      initial: initial,
      obstacles: [?insetRect],
    );
    if (insetRect != null && labels.rects.any(insetRect.overlaps)) {
      insetRect = null;
      labels = _placeLabels(
        geometry: geometry,
        l10n: l10n,
        style: style,
        scaler: scaler,
        initial: initial,
      );
    }
    return _DiagramLayout(
      labels: labels,
      insetOnTable: insetRect,
      insetWidth: insetWidth,
      insetBelow: inset != null && insetRect == null
          ? _below(inset, caption!, insetWidth, geometry)
          : null,
    );
  }

  /// Médaillon écrit sous la table : jamais plus large que la table, son
  /// libellé passe alors à la ligne (et sa hauteur en tient compte).
  ({ContactFraction contact, TipPoint tipPoint, double width, double height})
  _below(
    DiagramInset inset,
    TextPainter caption,
    double width,
    TableGeometry geometry,
  ) {
    final fitted = math.min(
      width,
      math.max<double>(0, geometry.tableRect.width - 2 * AppSpacing.xs),
    );
    caption.layout(maxWidth: fitted);
    return (
      contact: inset.contact,
      tipPoint: inset.tipPoint,
      width: fitted,
      height: _insetSize(fitted, caption.height).height,
    );
  }

  /// Encombrement du médaillon dont le schéma fait [width] et le libellé
  /// [captionHeight].
  Size _insetSize(double width, double captionHeight) => Size(
    width + 2 * AppSpacing.xs,
    width / BallContactDiagram.aspectWithTip +
        AppSpacing.sm +
        captionHeight +
        2 * AppSpacing.xs,
  );

  /// Médaillon de la quantité de bille : [width] est la largeur du schéma, le
  /// fond (surface du thème) l'entoure de [AppSpacing.xs].
  Widget _insetCard(
    BuildContext context,
    ContactFraction contact,
    TipPoint tipPoint,
    double width,
  ) {
    const pad = AppSpacing.xs;
    return SizedBox(
      key: const ValueKey('contact-inset'),
      width: width + 2 * pad,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(pad * 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(pad),
          child: BallContactDiagram(contact: contact, tipPoint: tipPoint),
        ),
      ),
    );
  }

  /// Emplacement de chaque étiquette (lettre de bille posée à côté, numéro de
  /// repère, annotation), calculé sur l'état [initial] du schéma. Les
  /// [obstacles] (médaillon) sont déjà posés.
  _LabelPlan _placeLabels({
    required TableGeometry geometry,
    required AppLocalizations l10n,
    required TextStyle? style,
    required TextScaler scaler,
    required DiagramFrame initial,
    List<Rect> obstacles = const [],
  }) {
    // Encombrements du texte (halo compris) pour chaque largeur maximale :
    // le premier est le préféré, les suivants sont plus étroits et plus hauts.
    List<Size> measure(String text) {
      final sizes = <Size>[];
      for (final share in _labelWidthShares) {
        final painter =
            TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: TextDirection.ltr,
              textScaler: scaler,
            )..layout(
              maxWidth: math.max(
                0,
                geometry.surface.width * share - _haloPadding * 2,
              ),
            );
        final size =
            painter.size + const Offset(_haloPadding * 2, _haloPadding * 2);
        if (sizes.isEmpty || size != sizes.last) sizes.add(size);
      }
      return sizes;
    }

    LabelRequest request(String text, Offset anchor, double radius) {
      final sizes = measure(text);
      return LabelRequest(
        anchor: anchor,
        size: sizes.first,
        anchorRadius: radius,
        alternatives: sizes.skip(1).toList(),
      );
    }

    final discs = _discs(geometry, initial);
    double anchorRadius(Offset anchor) => discs
        .where((d) => (d.center - anchor).distance <= d.radius + 0.5)
        .fold(0, (r, d) => math.max<double>(r, d.radius));

    final requests = <LabelRequest>[];
    final owners = <(String, String)>[];
    for (final ball in spec.balls) {
      final diameter = geometry.radiusPxOf(_kind(ball.color)) * 2;
      final text = _label(l10n, ball, diameter);
      if (text == null || diameter >= _letterInside) continue;
      final anchor = geometry.toPixel(_positionOf(initial, ball));
      requests.add(request(text, anchor, diameter / 2));
      owners.add(('ball', ball.id));
    }
    final plan = _LabelPlan();
    for (final ghost in spec.ghosts) {
      if (ghost.label == null) continue;
      final anchor = geometry.toPixel(_offset(ghost.at));
      if (_markFitsInside(geometry, ghost, anchor, initial)) {
        plan.insideGhosts.add(ghost.id);
        continue;
      }
      requests.add(request(ghost.label!, anchor, anchorRadius(anchor)));
      owners.add(('ghost', ghost.id));
    }
    for (final note in spec.annotations) {
      final anchor = geometry.toPixel(_offset(note.at));
      requests.add(request(note.text, anchor, anchorRadius(anchor)));
      owners.add(('note', note.id));
    }

    final placed = placeLabels(
      labels: requests,
      bounds: geometry.surface,
      paths: _paths(geometry, initial),
      discs: discs,
      obstacles: obstacles,
    );
    for (var i = 0; i < placed.length; i++) {
      final (kind, id) = owners[i];
      switch (kind) {
        case 'ball':
          plan.balls[id] = placed[i];
        case 'ghost':
          plan.ghosts[id] = placed[i];
        default:
          plan.notes[id] = placed[i];
      }
    }
    return plan;
  }

  /// Vrai si le numéro du cercle [ghost] s'écrit à l'intérieur : le cercle (de
  /// la taille de la blanche) mesure au moins [_letterInside] px, comme pour
  /// les lettres de bille, et aucune bille n'est posée en son centre.
  bool _markFitsInside(
    TableGeometry geometry,
    DiagramGhost ghost,
    Offset anchor,
    DiagramFrame initial,
  ) {
    if (ghost.role == DiagramGhostRole.contact) return false;
    if (geometry.ghostRadiusPx * 2 < _letterInside) return false;
    return !spec.balls.any(
      (b) =>
          (geometry.toPixel(_positionOf(initial, b)) - anchor).distance <
          geometry.ghostRadiusPx,
    );
  }

  /// Couleur de la bille [id] du schéma (la blanche à défaut).
  BallKind _colorOf(String id) {
    for (final ball in spec.balls) {
      if (ball.id == id) return _kind(ball.color);
    }
    return BallKind.white;
  }

  static String? _label(
    AppLocalizations l10n,
    DiagramBall ball,
    double diameter,
  ) {
    if (diameter >= _letterInside) return ball.label;
    final letter = ballKindLetter(l10n, _kind(ball.color));
    return ball.label == null ? letter : '$letter ${ball.label}';
  }
}

/// Étiquettes et médaillon d'un schéma, calculés pour une table donnée.
class _DiagramLayout {
  const _DiagramLayout({
    required this.labels,
    required this.insetOnTable,
    required this.insetWidth,
    required this.insetBelow,
  });

  final _LabelPlan labels;

  /// Rectangle du médaillon sur la table ; `null` s'il est sous la table ou
  /// absent.
  final Rect? insetOnTable;

  /// Largeur (px) du schéma du médaillon.
  final double insetWidth;

  /// Médaillon écrit sous la table faute de place libre dessus ; `null` sinon.
  final ({
    ContactFraction contact,
    TipPoint tipPoint,
    double width,
    double height,
  })?
  insetBelow;
}

/// Emplacements des étiquettes, par identifiant de bille, de cercle et
/// d'annotation.
class _LabelPlan {
  final balls = <String, LabelPlacement>{};
  final ghosts = <String, LabelPlacement>{};
  final notes = <String, LabelPlacement>{};

  /// Cercles dont le numéro est écrit à l'intérieur (pas d'emplacement).
  final insideGhosts = <String>{};

  List<Rect> get rects => [
    for (final map in [balls, ghosts, notes])
      for (final place in map.values) place.rect,
  ];
}

Offset _offset(DiagramPoint p) => Offset(p.x, p.y);

BallKind _kind(BallKind color) => switch (color) {
  BallKind.red => BallKind.red,
  BallKind.yellow => BallKind.yellow,
  BallKind.black => BallKind.black,
  BallKind.white => BallKind.white,
};

/// Peint ce qui est sous les billes : zones, flèches, repères de rebond et
/// cercles creux. Une seule teinte (`TableColors.headString`, contraste 3:1
/// testé sur le tapis) ; la nature se lit au trait.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.spec,
    required this.geometry,
    required this.ink,
  });

  final TableDiagramSpec spec;
  final TableGeometry geometry;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final u = geometry.unit;
    if (u <= 0) return;
    final width = math.max(1.5, u * 0.045);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final zone in spec.zones) {
      final rect = Rect.fromPoints(
        geometry.toPixel(_offset(zone.from)),
        geometry.toPixel(_offset(zone.to)),
      );
      canvas
        ..drawRect(rect, Paint()..color = ink.withValues(alpha: 0.18))
        ..drawRect(rect, line..strokeWidth = 1);
      line.strokeWidth = width;
    }

    for (final ghost in spec.ghosts) {
      if (ghost.role == DiagramGhostRole.contact) {
        // Point de contact : petit disque plein (rayon du procédé, 8,5 mm).
        canvas.drawCircle(
          geometry.toPixel(_offset(ghost.at)),
          math.max(
            2.5,
            BlackballDimensions.tipDiameterMm /
                2 /
                BlackballDimensions.cellMm *
                u,
          ),
          Paint()..color = ink,
        );
        continue;
      }
      final circle = Path()
        ..addOval(
          Rect.fromCircle(
            center: geometry.toPixel(_offset(ghost.at)),
            radius: geometry.ghostRadiusPx,
          ),
        );
      _drawDashed(canvas, circle, line, dash: u * 0.06, gap: u * 0.05);
    }

    for (final arrow in spec.arrows) {
      if (arrow.path.length < 2) continue;
      final points = TableDiagram.arrowPixelPoints(spec, arrow, geometry);
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      switch (arrow.kind) {
        case DiagramArrowKind.object:
          canvas.drawPath(path, line);
        case DiagramArrowKind.cue:
          _drawDashed(canvas, path, line, dash: u * 0.18, gap: u * 0.12);
        case DiagramArrowKind.aim:
          _drawPattern(canvas, path, line, [
            u * 0.3,
            u * 0.07,
            u * 0.03,
            u * 0.07,
          ]);
        case DiagramArrowKind.indication:
          _drawDashed(
            canvas,
            path,
            line..strokeWidth = width * 0.75,
            dash: u * 0.03,
            gap: u * 0.1,
          );
          line.strokeWidth = width;
      }
      _drawHead(canvas, points, u, line);
      for (final bounce in arrow.bouncePoints) {
        canvas.drawCircle(geometry.toPixel(_offset(bounce)), width * 1.6, line);
      }
    }
  }

  void _drawHead(Canvas canvas, List<Offset> points, double u, Paint line) {
    final tip = points.last;
    var from = points.length - 2;
    while (from > 0 && (tip - points[from]).distance == 0) {
      from--;
    }
    final back = points[from];
    final length = (tip - back).distance;
    if (length == 0) return;
    final direction = (tip - back) / length;
    final side = Offset(-direction.dy, direction.dx);
    final size = math.min(u * 0.22, length);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - direction.dx * size + side.dx * size * 0.45,
        tip.dy - direction.dy * size + side.dy * size * 0.45,
      )
      ..lineTo(
        tip.dx - direction.dx * size - side.dx * size * 0.45,
        tip.dy - direction.dy * size - side.dy * size * 0.45,
      )
      ..close();
    canvas.drawPath(head, Paint()..color = line.color);
  }

  /// Trait-point : [pattern] alterne longueurs tracées et blancs.
  void _drawPattern(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> pattern,
  ) {
    final steps = [for (final p in pattern) math.max(p, 0.5)];
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      var i = 0;
      while (d < metric.length) {
        final length = steps[i % steps.length];
        if (i.isEven) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + length, metric.length)),
            paint,
          );
        }
        d += length;
        i++;
      }
    }
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final step = math.max(dash, 0.5);
    final space = math.max(gap, 0.5);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += step + space) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + step, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.spec != spec ||
      old.geometry.surface != geometry.surface ||
      old.ink != ink;
}
