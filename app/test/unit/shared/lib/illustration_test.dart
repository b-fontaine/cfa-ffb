import 'dart:math' show Point;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/player_figure_layout.dart';
import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:flutter_test/flutter_test.dart';

String kindOf(Illustration illustration) => switch (illustration) {
  DiagramRefIllustration() => 'diagram_ref',
  TableIllustration() => 'table',
  ContactIllustration() => 'contact',
  ContactStripIllustration() => 'contact_strip',
  GhostAimIllustration() => 'ghost_aim',
  CueBallTargetIllustration() => 'cue_ball_target',
  PlayerFigureIllustration() => 'player_figure',
  BallSizeIllustration() => 'ball_size',
  PowerRatioIllustration() => 'power_ratio',
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
    const Illustration.cueBallTarget(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
      tipPoint: TipPoint.center,
      cueHeight: CueHeight.level,
    ),
    const Illustration.playerFigure(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
    ),
    const Illustration.ballSize(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
    ),
    const Illustration.powerRatio(
      id: 'i',
      caption: 'Légende',
      alt: 'Texte alternatif',
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

  test('has the eleven closed types of the sheet format', () {
    expect(all.map(kindOf), [
      'diagram_ref',
      'table',
      'contact',
      'contact_strip',
      'ghost_aim',
      'cue_ball_target',
      'player_figure',
      'ball_size',
      'power_ratio',
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

  test('a player figure shows the six marks of a right-handed player', () {
    final figure = all[6] as PlayerFigureIllustration;

    expect(figure.view, PlayerView.side);
    expect(figure.focus, PlayerMark.values);
    expect(figure.leadEye, isNull);
    expect(figure.headCase, isNull);
    expect(figure.bridge, CueBridge.frame);
  });

  test('a power ratio is an empty plane by default', () {
    final ratio = all[8] as PowerRatioIllustration;

    expect(ratio.points, isEmpty);
    expect(ratio.highlight, isNull);
    expect(ratio.distanceLabel, isNull);
  });

  test('a cue ball target compares no other point by default', () {
    final target = all[5] as CueBallTargetIllustration;

    expect(target.compare, isEmpty);
    expect(target.cueHeight, CueHeight.level);
  });

  test('a power point is read as a ratio of amplitude and speed', () {
    const point = PowerPoint(
      amplitude: AmplitudeLevel.short,
      speed: SpeedLevel.slow,
    );

    expect(point.zone, PowerZone.soft);
  });

  test('a shot step repeats once by default', () {
    expect(const IllustrationStep(cueId: 'w').repeat, 1);
  });
}
