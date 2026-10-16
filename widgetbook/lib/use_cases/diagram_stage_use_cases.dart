import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/cloth_pattern.dart';
import 'package:billard_cfa/shared/ui/diagram_stage.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/rotate_hint.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/diagram_examples.dart';

const _path = '[Design system]/Composants';

// --- DiagramStage ------------------------------------------------------------

/// La scène telle que la présentation la monte : tapis derrière, schéma sur le
/// reste de la hauteur, légende entière, barre précédent/suivant. Réduire la
/// hauteur de la zone d'aperçu (Widgetbook, appareils) pour voir le mode
/// compact (< 480 dp) puis le défilement (schéma < 160 dp).
Widget _stage(BuildContext context, {required String caption}) {
  const example = fullBall;
  return Stack(
    children: [
      const Positioned.fill(child: ClothPattern()),
      Padding(
        padding: const EdgeInsets.all(16),
        child: DiagramStage(
          title: context.knobs.string(
            label: 'titre',
            initialValue: 'Présentation : Entraînement',
          ),
          header: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.close),
              label: const Text('Fermer'),
            ),
          ),
          figureAspect: BilliardTable.aspect,
          figure: (context, zone) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: TableDiagramPlayer(
              maxHeight: zone.height,
              spec: example.spec,
              semanticLabel: example.description,
            ),
          ),
          caption: caption,
          badge: context.knobs.boolean(label: 'proposition')
              ? const ProposalBadge()
              : null,
          previous: FilledButton.tonalIcon(
            onPressed: null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Précédent'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
          next: FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.chevron_right),
            label: const Text('Suivant'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
    ],
  );
}

@widgetbook.UseCase(name: 'Interactif', type: DiagramStage, path: _path)
Widget buildDiagramStageUseCase(BuildContext context) => _stage(
  context,
  caption: context.knobs.string(
    label: 'légende',
    initialValue: 'Viser et empocher 6 billes placées en bord de poches.',
  ),
);

@widgetbook.UseCase(
  name: 'Légende la plus longue du catalogue',
  type: DiagramStage,
  path: _path,
)
Widget buildDiagramStageLongCaptionUseCase(BuildContext context) => _stage(
  context,
  caption:
      'Deux bandes : la blanche touche la grande bande du haut (1), puis la '
      'petite bande de droite (2), avant d’atteindre la bille rouge. La '
      'blanche, un peu plus petite que la rouge, est dessinée en creux au '
      'moment de chaque contact. Même visée en demi, depuis un autre endroit '
      ': la bille fantôme est collée à la bille de couleur, sur la ligne de '
      'la poche, côté opposé à la poche.',
);

// --- RotateHint --------------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: RotateHint, path: _path)
Widget buildRotateHintUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: RotateHint(onDismiss: () {}),
);

// --- PresentationCaption -----------------------------------------------------

@widgetbook.UseCase(
  name: 'Sur le motif de tapis',
  type: PresentationCaption,
  path: _path,
)
Widget buildPresentationCaptionUseCase(BuildContext context) => Stack(
  children: [
    const Positioned.fill(child: ClothPattern()),
    Center(
      child: PresentationScope(
        transparent: true,
        caption: context.knobs.string(
          label: 'légende',
          initialValue: 'Demi-bille : la blanche couvre la moitié de la bille.',
        ),
        child: const SizedBox(height: 40),
      ),
    ),
  ],
);
