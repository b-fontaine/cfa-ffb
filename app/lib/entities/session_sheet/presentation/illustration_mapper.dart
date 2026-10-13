import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/ui/angle_mark.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/ball_size_comparison.dart';
import 'package:billard_cfa/shared/ui/contact_strip.dart';
import 'package:billard_cfa/shared/ui/cue_ball_target.dart';
import 'package:billard_cfa/shared/ui/ghost_aim_diagram.dart';
import 'package:billard_cfa/shared/ui/pdf_page_chip.dart';
import 'package:billard_cfa/shared/ui/player_figure.dart';
import 'package:billard_cfa/shared/ui/power_ratio.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart'
    as ui;
import 'package:flutter/material.dart';

/// Rendu d'une [Illustration] de séance par les composants du design system.
///
/// Les 11 types de la liste fermée du FORMAT des séances (§ 6) sont rendus
/// ici, sans photo. Le texte alternatif (`alt`) de l'illustration est celui
/// que lisent les lecteurs d'écran. Un `diagram_ref` est résolu par
/// l'appelant (`diagrams`, par identifiant de diagramme) : cette entité
/// n'importe pas `exercise_diagram`.
abstract final class IllustrationMapper {
  /// Widget de [illustration]. [diagrams] donne le schéma de chaque
  /// identifiant de diagramme résolu ; un identifiant absent est signalé en
  /// clair (la séance reste lisible).
  static Widget build(
    BuildContext context,
    Illustration illustration, {
    required Map<String, ui.TableDiagramSpec> diagrams,
  }) {
    final alt = illustration.alt;
    switch (illustration) {
      case DiagramRefIllustration(:final diagramId):
        final spec = diagrams[diagramId];
        if (spec == null) {
          return Text(AppLocalizations.of(context).sheetIllustrationMissing);
        }
        return TableDiagramPlayer(spec: spec, semanticLabel: alt);
      case TableIllustration():
        return TableDiagramPlayer(
          spec: tableSpecOf(illustration),
          semanticLabel: alt,
        );
      case ContactIllustration(:final fraction, :final tipPoint):
        return _described(
          alt,
          BallContactDiagram(contact: fraction, tipPoint: tipPoint),
        );
      case ContactStripIllustration(:final fractions, :final highlight):
        return _described(
          alt,
          ContactStrip(fractions: fractions, highlight: highlight),
        );
      case GhostAimIllustration(
        :final cue,
        :final object,
        :final pocket,
        :final fraction,
      ):
        return _described(
          alt,
          GhostAimDiagram(
            cue: cue,
            object: object,
            pocket: pocket,
            fraction: fraction,
          ),
        );
      case CueBallTargetIllustration(
        :final tipPoint,
        :final compare,
        :final cueHeight,
      ):
        return _described(
          alt,
          CueBallTarget(
            tipPoint: tipPoint,
            compare: compare,
            cueHeight: cueHeight,
          ),
        );
      case BallSizeIllustration():
        return _described(alt, const BallSizeComparison());
      case PlayerFigureIllustration(
        :final view,
        :final focus,
        :final leadEye,
        :final headCase,
        :final bridge,
      ):
        return _described(
          alt,
          PlayerFigure(
            view: view,
            focus: focus,
            leadEye: leadEye,
            headCase: headCase,
            bridge: bridge,
          ),
        );
      case PowerRatioIllustration(
        :final points,
        :final highlight,
        :final distanceLabel,
      ):
        return _described(
          alt,
          PowerRatio(
            points: points,
            highlight: highlight,
            distanceLabel: distanceLabel,
          ),
        );
      case AngleIllustration(:final kind, :final vertex, :final rays):
        return _described(
          alt,
          AngleMark(kind: kind, vertex: vertex, rays: rays),
        );
      case PdfRefIllustration(:final file, :final page):
        return _described(alt, PdfPageChip(file: file, page: page));
    }
  }

  /// Le texte alternatif de la séance remplace la description générée du
  /// composant : un seul nœud sémantique, jamais deux lectures.
  static Widget _described(String alt, Widget child) => Semantics(
    label: alt,
    container: true,
    excludeSemantics: true,
    child: child,
  );

  /// Schéma du design system d'une illustration `table` : mêmes valeurs
  /// d'énumération des deux côtés (conversion sans perte).
  static ui.TableDiagramSpec tableSpecOf(TableIllustration table) =>
      ui.TableDiagramSpec(
        id: table.id,
        balls: [
          for (final b in table.balls)
            ui.DiagramBall(
              id: b.id,
              color: switch (b.color) {
                IllustrationBallColor.red => ui.BallKind.red,
                IllustrationBallColor.yellow => ui.BallKind.yellow,
                IllustrationBallColor.black => ui.BallKind.black,
                IllustrationBallColor.white => ui.BallKind.white,
              },
              at: b.at,
              role: switch (b.role) {
                IllustrationBallRole.cue => ui.DiagramBallRole.cue,
                IllustrationBallRole.object => ui.DiagramBallRole.object,
                IllustrationBallRole.obstacle => ui.DiagramBallRole.obstacle,
                null => null,
              },
              label: b.label,
              order: b.order,
            ),
        ],
        ghosts: [
          for (final g in table.ghosts)
            ui.DiagramGhost(
              id: g.id,
              at: g.at,
              role: switch (g.role) {
                IllustrationGhostRole.cueStart => ui.DiagramGhostRole.cueStart,
                IllustrationGhostRole.impact => ui.DiagramGhostRole.impact,
              },
              forBallId: g.forBallId,
              label: g.label,
            ),
        ],
        arrows: [
          for (final a in table.arrows)
            ui.DiagramArrow(
              id: a.id,
              kind: switch (a.kind) {
                IllustrationArrowKind.object => ui.DiagramArrowKind.object,
                IllustrationArrowKind.cue => ui.DiagramArrowKind.cue,
                IllustrationArrowKind.indication =>
                  ui.DiagramArrowKind.indication,
              },
              path: a.path,
              ballId: a.ballId,
              bounces: [
                for (final band in a.bounces)
                  switch (band) {
                    IllustrationBand.top => ui.DiagramBand.top,
                    IllustrationBand.bottom => ui.DiagramBand.bottom,
                    IllustrationBand.left => ui.DiagramBand.left,
                    IllustrationBand.right => ui.DiagramBand.right,
                  },
              ],
              pocket: _pocket(a.pocket),
              label: a.label,
              note: a.note,
            ),
        ],
        zones: [
          for (final z in table.zones)
            ui.DiagramZone(id: z.id, from: z.from, to: z.to, label: z.label),
        ],
        steps: [
          for (final s in table.steps)
            ui.DiagramStep(
              cueId: s.cueId,
              hitId: s.hitId,
              contact: s.contact,
              pocket: _pocket(s.pocket),
              repeat: s.repeat,
              fromGhostId: s.fromGhostId,
              extras: s.extras,
            ),
        ],
      );

  static ui.DiagramPocket? _pocket(TablePocket? pocket) => switch (pocket) {
    TablePocket.tl => ui.DiagramPocket.tl,
    TablePocket.tm => ui.DiagramPocket.tm,
    TablePocket.tr => ui.DiagramPocket.tr,
    TablePocket.bl => ui.DiagramPocket.bl,
    TablePocket.bm => ui.DiagramPocket.bm,
    TablePocket.br => ui.DiagramPocket.br,
    null => null,
  };
}
