import 'dart:math' as math;

import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/entities/session_sheet/presentation/illustration_mapper.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:flutter/material.dart';

/// Une illustration de la galerie, avec son origine.
class GalleryEntry {
  const GalleryEntry({
    required this.type,
    required this.illustration,
    required this.fromPilot,
  });

  /// Nom du `type` du FORMAT (`contact_strip`...).
  final String type;
  final Illustration illustration;

  /// Vrai quand l'illustration vient du fichier pilote ; faux pour un exemple
  /// (le pilote n'utilise pas ce type).
  final bool fromPilot;
}

/// Les 11 types du FORMAT, dans l'ordre du § 6. Pour chaque type, la première
/// illustration du pilote, sinon un exemple écrit ici.
List<GalleryEntry> galleryEntries(List<Illustration> pilot) {
  Illustration? pick(bool Function(Illustration) test) {
    for (final i in pilot) {
      if (test(i)) return i;
    }
    return null;
  }

  GalleryEntry entry(
    String type,
    Illustration? fromPilot,
    Illustration example,
  ) => GalleryEntry(
    type: type,
    illustration: fromPilot ?? example,
    fromPilot: fromPilot != null,
  );

  return [
    entry(
      'diagram_ref',
      pick((i) => i is DiagramRefIllustration),
      const Illustration.diagramRef(
        id: 'ex-diagram',
        caption: 'Initiation 7 : la rouge est jouée en demi.',
        alt: 'Schéma transcrit de l’initiation 7.',
        diagramId: 'initiation-p07-e1',
      ),
    ),
    entry(
      'table',
      pick((i) => i is TableIllustration),
      const Illustration.table(
        id: 'ex-table',
        caption: 'Deux billes alignées sur la poche du milieu.',
        alt: 'Table vue de dessus : une blanche, une rouge et une flèche.',
        balls: [
          IllustrationBall(
            id: 'cue',
            color: IllustrationBallColor.white,
            at: math.Point(2, 3),
          ),
          IllustrationBall(
            id: 'red',
            color: IllustrationBallColor.red,
            at: math.Point(4, 2),
          ),
        ],
        arrows: [
          IllustrationArrow(
            id: 'a',
            kind: IllustrationArrowKind.object,
            path: [math.Point(4, 2), math.Point(4, 0)],
          ),
        ],
      ),
    ),
    entry(
      'contact',
      pick((i) => i is ContactIllustration),
      const Illustration.contact(
        id: 'ex-contact',
        caption: 'Demi-bille, procédé au centre.',
        alt: 'La blanche couvre la moitié de la bille de couleur.',
        fraction: ContactFraction.half,
        tipPoint: TipPoint.center,
      ),
    ),
    entry(
      'contact_strip',
      pick((i) => i is ContactStripIllustration),
      const Illustration.contactStrip(
        id: 'ex-strip',
        caption: 'Les cinq quantités de bille.',
        alt: 'Cinq schémas de contact.',
        fractions: ContactFraction.values,
        highlight: ContactFraction.half,
      ),
    ),
    entry(
      'ghost_aim',
      pick((i) => i is GhostAimIllustration),
      const Illustration.ghostAim(
        id: 'ex-aim',
        caption: 'La bille fantôme montre où la blanche touche la cible.',
        alt: 'Blanche, bille de couleur, poche et bille fantôme.',
        cue: math.Point(1.84, 2.26),
        object: math.Point(5, 2),
        pocket: TablePocket.tr,
        fraction: ContactFraction.half,
      ),
    ),
    entry(
      'cue_ball_target',
      pick((i) => i is CueBallTargetIllustration),
      const Illustration.cueBallTarget(
        id: 'ex-target',
        caption: 'Procédé en bas de la blanche, talon relevé.',
        alt: 'La blanche vue de face avec une cible et le point d’impact.',
        tipPoint: TipPoint.bottom,
        cueHeight: CueHeight.high,
      ),
    ),
    entry(
      'player_figure',
      pick((i) => i is PlayerFigureIllustration),
      const Illustration.playerFigure(
        id: 'ex-figure',
        caption: 'La posture : pieds, jambes, tête, avant-bras, chevalet.',
        alt: 'Un joueur schématique de profil, six repères numérotés.',
      ),
    ),
    entry(
      'ball_size',
      pick((i) => i is BallSizeIllustration),
      const Illustration.ballSize(
        id: 'ex-size',
        caption: 'La blanche est un peu plus petite que la bille de couleur.',
        alt: 'La blanche, 48,0 mm, et une bille de couleur, 50,8 mm.',
      ),
    ),
    entry(
      'contact_height',
      pick((i) => i is ContactHeightIllustration),
      const Illustration.contactHeight(
        id: 'ex-height',
        caption:
            'Au contact, la blanche touche la bille de couleur légèrement '
            "au-dessus de l'équateur de la blanche (inclinaison exagérée ×10, "
            "ce n'est pas une mesure).",
        alt:
            'Vue de côté : la blanche et une bille de couleur, plus grosse, '
            'posées sur le tapis ; le point de contact est légèrement '
            "au-dessus de l'équateur de la blanche, inclinaison exagérée.",
      ),
    ),
    entry(
      'power_ratio',
      pick((i) => i is PowerRatioIllustration),
      const Illustration.powerRatio(
        id: 'ex-power',
        caption: 'Doser : recul de la main et vitesse du coup.',
        alt: 'Plan amplitude et vitesse avec trois zones.',
        points: [
          PowerPoint(amplitude: AmplitudeLevel.long, speed: SpeedLevel.fast),
        ],
        highlight: 0,
        distanceLabel: 'La blanche va loin',
      ),
    ),
    entry(
      'angle',
      pick((i) => i is AngleIllustration),
      const Illustration.angle(
        id: 'ex-angle',
        caption: 'Le coup à angle droit.',
        alt: 'Deux trajectoires à angle droit sur la table.',
        kind: AngleKind.rightAngle,
        vertex: math.Point(5, 2),
        rays: [math.Point(7, 2), math.Point(5, 0.3)],
      ),
    ),
    entry(
      'pdf_ref',
      pick((i) => i is PdfRefIllustration),
      const Illustration.pdfRef(
        id: 'ex-pdf',
        caption: 'Fiche technique n° 5.',
        alt: 'Renvoi à la page 15 du PDF des fiches techniques.',
        file: 'Fiches techniques CFA BàP.pdf',
        page: 15,
      ),
    ),
  ];
}

/// Carte de la galerie : type, origine, rendu et légende ; en mode
/// présentation, l'illustration est montrée agrandie avec sa légende.
class GalleryCard extends StatelessWidget {
  const GalleryCard({
    required this.entry,
    required this.library,
    required this.presenting,
    super.key,
  });

  final GalleryEntry entry;
  final DiagramLibrary library;
  final bool presenting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final illustration = entry.illustration;
    final rendered = renderIllustration(illustration, library);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.type, style: theme.textTheme.titleMedium),
            Text(
              entry.fromPilot ? 'pilote demi-bille-1' : 'exemple hors pilote',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            if (presenting)
              PresentationScope(caption: illustration.caption, child: rendered)
            else ...[
              rendered,
              const SizedBox(height: 8),
              Text(illustration.caption, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rendu d'une illustration du domaine par les composants du design system :
/// celui de l'application (`IllustrationMapper`), les schémas transcrits étant
/// résolus ici dans la bibliothèque.
Widget renderIllustration(Illustration illustration, DiagramLibrary library) =>
    Builder(
      builder: (context) => IllustrationMapper.build(
        context,
        illustration,
        diagrams: {
          for (final diagram in library.diagrams)
            diagram.id: tableDiagramSpecOf(diagram),
        },
      ),
    );
