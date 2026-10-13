import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/ui/angle_mark.dart';
import 'package:billard_cfa/shared/ui/contact_strip.dart';
import 'package:billard_cfa/shared/ui/cue_ball_target.dart';
import 'package:billard_cfa/shared/ui/cue_side_view.dart';
import 'package:billard_cfa/shared/ui/ghost_aim_diagram.dart';
import 'package:billard_cfa/shared/ui/pdf_page_chip.dart';
import 'package:billard_cfa/shared/ui/player_figure.dart';
import 'package:billard_cfa/shared/ui/power_ratio.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Illustrations';

double _width(BuildContext context, {double initial = 480}) => context
    .knobs
    .double
    .slider(label: 'largeur', initialValue: initial, min: 120, max: 720);

Widget _page(double width, Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: width, child: child),
  ),
);

Widget _labelled(String title, Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    child,
  ],
);

// --- ContactStrip -----------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: ContactStrip, path: _path)
Widget buildContactStripUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  ContactStrip(
    fractions: [
      for (final fraction in ContactFraction.values)
        if (context.knobs.boolean(label: fraction.name, initialValue: true))
          fraction,
    ],
    highlight: context.knobs.objectOrNull.dropdown<ContactFraction>(
      label: 'mise en évidence',
      options: ContactFraction.values,
      initialOption: ContactFraction.half,
      labelBuilder: (value) => value.name,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Largeur réduite (passage à la ligne)',
  type: ContactStrip,
  path: _path,
)
Widget buildContactStripNarrowUseCase(BuildContext context) => _page(
  _width(context, initial: 220),
  const ContactStrip(
    fractions: ContactFraction.values,
    highlight: ContactFraction.thin,
  ),
);

@widgetbook.UseCase(name: 'Liste vide', type: ContactStrip, path: _path)
Widget buildContactStripEmptyUseCase(BuildContext context) =>
    _page(_width(context), const ContactStrip(fractions: []));

// --- GhostAimDiagram --------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: GhostAimDiagram, path: _path)
Widget buildGhostAimUseCase(BuildContext context) {
  double slider(String label, double initial, double max) => context
      .knobs
      .double
      .slider(label: label, initialValue: initial, min: 0.3, max: max);
  return _page(
    _width(context, initial: 560),
    GhostAimDiagram(
      cue: math.Point(
        slider('blanche x', 1.84, 7.7),
        slider('blanche y', 2.26, 3.7),
      ),
      object: math.Point(slider('cible x', 5, 7.7), slider('cible y', 2, 3.7)),
      pocket: context.knobs.object.dropdown<TablePocket>(
        label: 'poche',
        options: TablePocket.values,
        initialOption: TablePocket.tr,
        labelBuilder: (value) => value.name,
      ),
      fraction: context.knobs.object.dropdown<ContactFraction>(
        label: 'quantité annoncée',
        options: ContactFraction.values,
        initialOption: ContactFraction.half,
        labelBuilder: (value) => value.name,
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Bille pleine (alignée sur la poche)',
  type: GhostAimDiagram,
  path: _path,
)
Widget buildGhostAimFullUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const GhostAimDiagram(
    cue: math.Point(4, 3.6),
    object: math.Point(4, 1.6),
    pocket: TablePocket.tm,
    fraction: ContactFraction.full,
  ),
);

@widgetbook.UseCase(
  name: 'Quart de bille, largeur réduite',
  type: GhostAimDiagram,
  path: _path,
)
Widget buildGhostAimNarrowUseCase(BuildContext context) => _page(
  _width(context, initial: 240),
  const GhostAimDiagram(
    cue: math.Point(2.5, 3.3),
    object: math.Point(5, 2),
    pocket: TablePocket.tr,
    fraction: ContactFraction.quarter,
  ),
);

// --- CueSideView ------------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: CueSideView, path: _path)
Widget buildCueSideViewUseCase(BuildContext context) => _page(
  _width(context, initial: 520),
  CueSideView(
    tipPoint: context.knobs.object.dropdown<TipPoint>(
      label: 'point du procédé',
      options: TipPoint.values,
      labelBuilder: (value) => value.name,
    ),
    cueHeight: context.knobs.object.dropdown<CueHeight>(
      label: 'hauteur du talon',
      options: CueHeight.values,
      labelBuilder: (value) => value.name,
    ),
    bridge: context.knobs.objectOrNull.dropdown<CueBridge>(
      label: 'chevalet',
      options: CueBridge.values,
      initialOption: CueBridge.surface,
      labelBuilder: (value) => value.name,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Hauteurs et chevalets',
  type: CueSideView,
  path: _path,
)
Widget buildCueSideViewAllUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final height in CueHeight.values)
        for (final bridge in <CueBridge?>[null, ...CueBridge.values])
          SizedBox(
            width: 300,
            child: CueSideView(
              tipPoint: TipPoint.center,
              cueHeight: height,
              bridge: bridge,
            ),
          ),
    ],
  ),
);

@widgetbook.UseCase(
  name: "Contact au-dessus de l'équateur de la blanche (écart exagéré ×10)",
  type: CueSideView,
  path: _path,
)
Widget buildCueSideViewContactUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const CueSideView(
    tipPoint: TipPoint.center,
    cueHeight: CueHeight.level,
    showContact: true,
  ),
);

@widgetbook.UseCase(
  name: 'Point du procédé de côté (gauche : au centre)',
  type: CueSideView,
  path: _path,
)
Widget buildCueSideViewTipsUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final tip in TipPoint.values)
        SizedBox(
          width: 260,
          child: CueSideView(tipPoint: tip, cueHeight: CueHeight.level),
        ),
    ],
  ),
);

// --- CueBallTarget ----------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: CueBallTarget, path: _path)
Widget buildCueBallTargetUseCase(BuildContext context) => _page(
  _width(context, initial: 420),
  CueBallTarget(
    tipPoint: context.knobs.object.dropdown<TipPoint>(
      label: 'point d’impact du procédé',
      options: TipPoint.values,
      labelBuilder: (value) => value.name,
    ),
    cueHeight: context.knobs.objectOrNull.dropdown<CueHeight>(
      label: 'profil de la queue',
      options: CueHeight.values,
      initialOption: CueHeight.level,
      labelBuilder: (value) => value.name,
    ),
    compare: [
      for (final tip in TipPoint.values)
        if (context.knobs.boolean(label: 'comparer : ${tip.name}')) tip,
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Les neuf points d’impact',
  type: CueBallTarget,
  path: _path,
)
Widget buildCueBallTargetAllUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final tip in TipPoint.values)
        SizedBox(width: 300, child: CueBallTarget(tipPoint: tip)),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Comparaison centre, haut, bas',
  type: CueBallTarget,
  path: _path,
)
Widget buildCueBallTargetCompareUseCase(BuildContext context) => _page(
  _width(context, initial: 420),
  const CueBallTarget(
    tipPoint: TipPoint.center,
    compare: [TipPoint.top, TipPoint.bottom],
  ),
);

@widgetbook.UseCase(
  name: 'Avec le profil de la queue',
  type: CueBallTarget,
  path: _path,
)
Widget buildCueBallTargetProfileUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final height in CueHeight.values)
        SizedBox(
          width: 320,
          child: CueBallTarget(tipPoint: TipPoint.bottom, cueHeight: height),
        ),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Largeur réduite (procédé agrandi)',
  type: CueBallTarget,
  path: _path,
)
Widget buildCueBallTargetNarrowUseCase(BuildContext context) => _page(
  _width(context, initial: 240),
  const CueBallTarget(tipPoint: TipPoint.topRight),
);

// --- PlayerFigure -----------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: PlayerFigure, path: _path)
Widget buildPlayerFigureUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  PlayerFigure(
    view: context.knobs.object.dropdown<PlayerView>(
      label: 'vue',
      options: PlayerView.values,
      labelBuilder: (value) => value.name,
    ),
    focus: [
      for (final mark in PlayerMark.values)
        if (context.knobs.boolean(
          label: 'repère : ${mark.name}',
          initialValue: true,
        ))
          mark,
    ],
    leadEye: context.knobs.object.dropdown<LeadEye>(
      label: 'œil directeur',
      options: LeadEye.values,
      labelBuilder: (value) => value.name,
    ),
    headCase: context.knobs.objectOrNull.dropdown<HeadCase>(
      label: 'place de la tête',
      options: HeadCase.values,
      labelBuilder: (value) => value.name,
    ),
    bridge: context.knobs.object.dropdown<CueBridge>(
      label: 'chevalet',
      options: CueBridge.values,
      labelBuilder: (value) => value.name,
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Profil, chevalet sur surface',
  type: PlayerFigure,
  path: _path,
)
Widget buildPlayerFigureSurfaceUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const PlayerFigure(bridge: CueBridge.surface),
);

@widgetbook.UseCase(
  name: 'Vue de dessus, œil droit sur la queue',
  type: PlayerFigure,
  path: _path,
)
Widget buildPlayerFigureTopUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const PlayerFigure(view: PlayerView.top, headCase: HeadCase.rightEyeOverCue),
);

@widgetbook.UseCase(
  name: 'Les trois places de la tête',
  type: PlayerFigure,
  path: _path,
)
Widget buildPlayerFigureHeadCasesUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final headCase in HeadCase.values)
        SizedBox(
          width: 420,
          child: PlayerFigure(
            view: PlayerView.top,
            focus: const [PlayerMark.head],
            headCase: headCase,
            leadEye: headCase == HeadCase.leftEyeOverCue
                ? LeadEye.left
                : LeadEye.right,
          ),
        ),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Trois repères seulement (séance enfants)',
  type: PlayerFigure,
  path: _path,
)
Widget buildPlayerFigureFocusUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const PlayerFigure(
    focus: [PlayerMark.feet, PlayerMark.legsAndHips, PlayerMark.cue],
  ),
);

@widgetbook.UseCase(
  name: 'Profil et dessus (large)',
  type: PlayerFigure,
  path: _path,
)
Widget buildPlayerFigureBothUseCase(BuildContext context) => _page(
  _width(context, initial: 960),
  const PlayerFigure(view: PlayerView.both),
);

// --- PowerRatio -------------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: PowerRatio, path: _path)
Widget buildPowerRatioUseCase(BuildContext context) {
  PowerPoint? point(String name, {required bool initial}) {
    if (!context.knobs.boolean(label: 'exemple $name', initialValue: initial)) {
      return null;
    }
    return PowerPoint(
      amplitude: context.knobs.object.dropdown<AmplitudeLevel>(
        label: 'amplitude $name',
        options: AmplitudeLevel.values,
        labelBuilder: (value) => value.name,
      ),
      speed: context.knobs.object.dropdown<SpeedLevel>(
        label: 'vitesse $name',
        options: SpeedLevel.values,
        labelBuilder: (value) => value.name,
      ),
    );
  }

  final points = [?point('1', initial: true), ?point('2', initial: false)];
  final highlight = context.knobs.int.slider(
    label: 'exemple en évidence (0 : aucun)',
    max: 2,
  );
  final distance = context.knobs.string(label: 'repère de distance');
  return _page(
    _width(context, initial: 420),
    PowerRatio(
      points: points,
      highlight: highlight < 1 || highlight > points.length
          ? null
          : highlight - 1,
      distanceLabel: distance.isEmpty ? null : distance,
    ),
  );
}

@widgetbook.UseCase(name: 'Plan seul', type: PowerRatio, path: _path)
Widget buildPowerRatioEmptyUseCase(BuildContext context) =>
    _page(_width(context, initial: 420), const PowerRatio());

@widgetbook.UseCase(
  name: 'Les deux extrêmes de la fiche n° 2',
  type: PowerRatio,
  path: _path,
)
Widget buildPowerRatioExtremesUseCase(BuildContext context) => _page(
  _width(context, initial: 420),
  const PowerRatio(
    points: [
      PowerPoint(
        amplitude: AmplitudeLevel.short,
        speed: SpeedLevel.slow,
        label: 'Bille proche',
      ),
      PowerPoint(
        amplitude: AmplitudeLevel.long,
        speed: SpeedLevel.fast,
        label: 'Bille lointaine',
      ),
    ],
    highlight: 1,
  ),
);

@widgetbook.UseCase(
  name: 'Les neuf combinaisons',
  type: PowerRatio,
  path: _path,
)
Widget buildPowerRatioGridUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final amplitude in AmplitudeLevel.values)
        for (final speed in SpeedLevel.values)
          SizedBox(
            width: 300,
            child: PowerRatio(
              points: [PowerPoint(amplitude: amplitude, speed: speed)],
            ),
          ),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Largeur réduite, avec repère',
  type: PowerRatio,
  path: _path,
)
Widget buildPowerRatioNarrowUseCase(BuildContext context) => _page(
  _width(context, initial: 260),
  const PowerRatio(
    points: [
      PowerPoint(amplitude: AmplitudeLevel.long, speed: SpeedLevel.fast),
    ],
    highlight: 0,
    distanceLabel: 'Jusqu’à la bande du fond et retour',
  ),
);

// --- AngleMark --------------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: AngleMark, path: _path)
Widget buildAngleMarkUseCase(BuildContext context) {
  double slider(String label, double initial, double max) => context
      .knobs
      .double
      .slider(label: label, initialValue: initial, max: max);
  return _page(
    _width(context, initial: 560),
    AngleMark(
      kind: context.knobs.object.dropdown<AngleKind>(
        label: 'nature',
        options: AngleKind.values,
        labelBuilder: (value) => value.name,
      ),
      vertex: math.Point(slider('sommet x', 4, 8), slider('sommet y', 2, 4)),
      rays: [
        math.Point(slider('rayon 1 x', 6, 8), slider('rayon 1 y', 2, 4)),
        math.Point(slider('rayon 2 x', 4, 8), slider('rayon 2 y', 0.2, 4)),
      ],
    ),
  );
}

@widgetbook.UseCase(name: 'Angle droit', type: AngleMark, path: _path)
Widget buildAngleMarkRightUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const AngleMark(
    kind: AngleKind.rightAngle,
    vertex: math.Point(5, 2),
    rays: [math.Point(7, 2), math.Point(5, 0.3)],
  ),
);

@widgetbook.UseCase(name: 'Rebond sur une bande', type: AngleMark, path: _path)
Widget buildAngleMarkBounceUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const AngleMark(
    kind: AngleKind.bounce,
    vertex: math.Point(4, 4),
    rays: [math.Point(2, 1.5), math.Point(6, 1.5)],
  ),
);

@widgetbook.UseCase(
  name: 'Un seul rayon (aucun angle)',
  type: AngleMark,
  path: _path,
)
Widget buildAngleMarkSingleUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const AngleMark(
    kind: AngleKind.naturalRejection,
    vertex: math.Point(4, 4),
    rays: [math.Point(6, 2)],
  ),
);

// --- PdfPageChip ------------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: PdfPageChip, path: _path)
Widget buildPdfPageChipUseCase(BuildContext context) => _page(
  _width(context, initial: 360),
  Align(
    alignment: Alignment.centerLeft,
    child: PdfPageChip(
      file: context.knobs.string(
        label: 'fichier',
        initialValue: 'Fiches techniques CFA BàP.pdf',
      ),
      page: context.knobs.int.slider(
        label: 'page',
        initialValue: 15,
        min: 1,
        max: 40,
      ),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Nom de fichier très long, largeur réduite',
  type: PdfPageChip,
  path: _path,
)
Widget buildPdfPageChipLongUseCase(BuildContext context) => _page(
  _width(context, initial: 180),
  const PdfPageChip(
    file: 'Un nom de fichier fédéral vraiment très très long pour tester.pdf',
    page: 12,
  ),
);

// --- PresentationScope ------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: PresentationScope, path: _path)
Widget buildPresentationScopeUseCase(BuildContext context) =>
    SingleChildScrollView(
      child: PresentationScope(
        scale: context.knobs.double.slider(
          label: 'agrandissement',
          initialValue: 1.5,
          min: 1,
          max: 2.5,
        ),
        caption: context.knobs.string(
          label: 'légende',
          initialValue: 'Demi-bille : la blanche couvre la moitié de la bille.',
        ),
        child: const SizedBox(
          width: 420,
          child: ContactStrip(
            fractions: ContactFraction.values,
            highlight: ContactFraction.half,
          ),
        ),
      ),
    );

@widgetbook.UseCase(
  name: 'Sans légende, avec une visée',
  type: PresentationScope,
  path: _path,
)
Widget buildPresentationScopeAimUseCase(BuildContext context) =>
    SingleChildScrollView(
      child: PresentationScope(
        child: _labelled(
          'Visée à la bille fantôme',
          const SizedBox(
            width: 520,
            child: GhostAimDiagram(
              cue: math.Point(1.84, 2.26),
              object: math.Point(5, 2),
              pocket: TablePocket.tr,
              fraction: ContactFraction.half,
            ),
          ),
        ),
      ),
    );
