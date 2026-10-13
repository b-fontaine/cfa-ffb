import 'dart:math' show Point;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:flutter_test/flutter_test.dart';

String kindOf(Illustration illustration) => switch (illustration) {
  DiagramRefIllustration() => 'diagram_ref',
  TableIllustration() => 'table',
  ContactIllustration() => 'contact',
  ContactStripIllustration() => 'contact_strip',
  GhostAimIllustration() => 'ghost_aim',
  CueSideIllustration() => 'cue_side',
  StanceTopIllustration() => 'stance_top',
  PowerScaleIllustration() => 'power_scale',
  AngleIllustration() => 'angle',
  PdfRefIllustration() => 'pdf_ref',
};

void main() {
  const common = (id: 'i', caption: 'Légende', alt: 'Texte alternatif');
  final all = <Illustration>[
    const Illustration.diagramRef(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      diagramId: 'initiation-p07-e1',
    ),
    const Illustration.table(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      balls: [],
    ),
    const Illustration.contact(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      fraction: ContactFraction.half,
      tipPoint: TipPoint.topLeft,
    ),
    const Illustration.contactStrip(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      fractions: [ContactFraction.full, ContactFraction.half],
    ),
    const Illustration.ghostAim(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      cue: Point(1, 2),
      object: Point(5, 2),
      pocket: TablePocket.tr,
      fraction: ContactFraction.half,
    ),
    const Illustration.cueSide(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      tipPoint: TipPoint.center,
      cueHeight: CueHeight.level,
    ),
    const Illustration.stanceTop(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
    ),
    const Illustration.powerScale(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      levels: 5,
    ),
    const Illustration.angle(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      kind: AngleKind.bounce,
      vertex: Point(4, 0),
      rays: [Point(2, 2), Point(6, 2)],
    ),
    const Illustration.pdfRef(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      file: 'Fiches techniques CFA BàP.pdf',
      page: 15,
    ),
  ];

  test('has the ten closed types of the sheet format', () {
    expect(all.map(kindOf), [
      'diagram_ref',
      'table',
      'contact',
      'contact_strip',
      'ghost_aim',
      'cue_side',
      'stance_top',
      'power_scale',
      'angle',
      'pdf_ref',
    ]);
  });

  test('every type carries an id, a caption and an alternative text', () {
    for (final illustration in all) {
      expect(illustration.id, common.id);
      expect(illustration.caption, common.caption);
      expect(illustration.alt, common.alt);
    }
  });

  test('is equal by value', () {
    expect(
      const Illustration.pdfRef(
        id: 'a',
        caption: 'c',
        alt: 't',
        file: 'f.pdf',
        page: 1,
      ),
      const Illustration.pdfRef(
        id: 'a',
        caption: 'c',
        alt: 't',
        file: 'f.pdf',
        page: 1,
      ),
    );
    expect(all.first == all.last, isFalse);
  });

  test('defaults optional table content to empty lists', () {
    final table = all[1] as TableIllustration;

    expect(table.ghosts, isEmpty);
    expect(table.arrows, isEmpty);
    expect(table.zones, isEmpty);
    expect(table.steps, isEmpty);
  });

  test('a shot step repeats once by default', () {
    expect(const IllustrationStep(cueId: 'w').repeat, 1);
  });
}
