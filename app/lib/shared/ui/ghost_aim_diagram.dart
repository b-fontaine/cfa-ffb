import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/ghost_ball_geometry.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart' as geometry;
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
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
class GhostAimDiagram extends StatelessWidget {
  const GhostAimDiagram({
    required this.cue,
    required this.object,
    required this.pocket,
    required this.fraction,
    super.key,
  });

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
    return TableDiagram(
      spec: buildSpec(
        cue: cue,
        object: object,
        pocket: pocket,
        ghostName: l10n.ghostBallName,
      ),
      semanticLabel: l10n.ghostAimLabel(
        BallContactDiagram.contactLabel(l10n, fraction),
        _pocketName(l10n, pocket),
      ),
      showHeadString: false,
    );
  }
}
