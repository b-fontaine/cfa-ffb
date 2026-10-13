import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/ui/angle_mark.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/contact_strip.dart';
import 'package:billard_cfa/shared/ui/cue_side_view.dart';
import 'package:billard_cfa/shared/ui/ghost_aim_diagram.dart';
import 'package:billard_cfa/shared/ui/pdf_page_chip.dart';
import 'package:billard_cfa/shared/ui/power_scale.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/stance_diagram.dart';
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
        slider('blanche y', 2.31, 3.7),
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

// --- StanceDiagram ----------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: StanceDiagram, path: _path)
Widget buildStanceDiagramUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  StanceDiagram(
    leadEye: context.knobs.object.dropdown<StanceLeadEye>(
      label: 'œil directeur',
      options: StanceLeadEye.values,
      labelBuilder: (value) => value.name,
    ),
    annotations: [
      for (
        var i = 1;
        i <= context.knobs.int.slider(label: 'annotations', max: 4);
        i++
      )
        'Point d’attention $i',
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Avec annotations de la séance',
  type: StanceDiagram,
  path: _path,
)
Widget buildStanceDiagramNotesUseCase(BuildContext context) => _page(
  _width(context, initial: 560),
  const StanceDiagram(
    annotations: [
      'Le pied droit est sous la main droite qui tient la queue.',
      'L’avant-bras droit est vertical.',
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Largeur réduite, œil gauche',
  type: StanceDiagram,
  path: _path,
)
Widget buildStanceDiagramNarrowUseCase(BuildContext context) => _page(
  _width(context, initial: 260),
  const StanceDiagram(leadEye: StanceLeadEye.left),
);

// --- PowerScale -------------------------------------------------------------

@widgetbook.UseCase(name: 'Interactif', type: PowerScale, path: _path)
Widget buildPowerScaleUseCase(BuildContext context) {
  final levels = context.knobs.int.slider(
    label: 'niveaux',
    initialValue: 5,
    min: 1,
    max: 5,
  );
  final highlight = context.knobs.int.slider(
    label: 'niveau en évidence (0 : aucun)',
    initialValue: 3,
    max: 5,
  );
  final distance = context.knobs.string(
    label: 'repère de distance',
    initialValue: 'La blanche s’arrête dans la zone grise',
  );
  return _page(
    _width(context, initial: 360),
    PowerScale(
      levels: levels,
      highlight: highlight < 1 || highlight > levels ? null : highlight,
      distanceLabel: distance.isEmpty ? null : distance,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Un seul niveau, sans repère',
  type: PowerScale,
  path: _path,
)
Widget buildPowerScaleSingleUseCase(BuildContext context) => _page(
  _width(context, initial: 200),
  const PowerScale(levels: 1, highlight: 1),
);

@widgetbook.UseCase(
  name: 'Cinq niveaux, largeur réduite',
  type: PowerScale,
  path: _path,
)
Widget buildPowerScaleNarrowUseCase(BuildContext context) => _page(
  _width(context, initial: 160),
  const PowerScale(
    levels: 5,
    highlight: 5,
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
              cue: math.Point(1.84, 2.31),
              object: math.Point(5, 2),
              pocket: TablePocket.tr,
              fraction: ContactFraction.half,
            ),
          ),
        ),
      ),
    );
