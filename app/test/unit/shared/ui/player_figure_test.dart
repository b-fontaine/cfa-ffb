import 'package:billard_cfa/shared/ui/player_figure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

const _fr = Locale('fr');

Finder _legend(int n) => find.byKey(ValueKey('player-legend-$n'));
Finder _badge(int n) => find.byKey(ValueKey('player-badge-$n'));

Future<void> _size(WidgetTester tester, double width, [double height = 1600]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pump();
}

/// Taille effective d'un `Text` : style hérité fusionné avec le sien.
double _effectiveSize(Element element) {
  final text = element.widget as Text;
  final merged = DefaultTextStyle.of(element).style.merge(text.style);
  return merged.fontSize ?? double.nan;
}

void main() {
  testWidgets('legends the six marks, numbered, in the order of the sheet', (
    tester,
  ) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(child: PlayerFigure()),
      locale: _fr,
    );

    for (var n = 1; n <= 6; n++) {
      expect(_legend(n), findsOneWidget, reason: 'legend $n');
    }
    expect(
      find.text(
        'Pieds : ni trop serrés, ni trop espacés ; le pied droit sous la '
        'main qui tient la queue',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Avant-bras : vertical, seul le coude bouge'),
      findsOneWidget,
    );
    final tops = [
      for (var n = 1; n <= 6; n++) tester.getTopLeft(_legend(n)).dy,
    ];
    expect(tops, [...tops]..sort());
  });

  testWidgets('puts a numbered badge of 28 px or more on the drawing', (
    tester,
  ) async {
    await _size(tester, 400);
    await pumpUi(tester, const SingleChildScrollView(child: PlayerFigure()));

    for (var n = 1; n <= 6; n++) {
      final size = tester.getSize(_badge(n));

      expect(size.width, greaterThanOrEqualTo(28), reason: 'badge $n');
      expect(size.height, greaterThanOrEqualTo(28));
    }
  });

  testWidgets('keeps the badges inside the drawing and apart', (tester) async {
    await _size(tester, 360);
    await pumpUi(tester, const SingleChildScrollView(child: PlayerFigure()));

    final drawing = tester.getRect(
      find.byKey(const ValueKey('player-figure-side')),
    );
    final rects = [for (var n = 1; n <= 6; n++) tester.getRect(_badge(n))];
    for (final r in rects) {
      expect(drawing.contains(r.topLeft), isTrue);
      expect(drawing.contains(r.bottomRight), isTrue);
    }
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: 'badges ${i + 1} and ${j + 1}',
        );
      }
    }
  });

  testWidgets('fades the marks out of the focus and drops their legend', (
    tester,
  ) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(
        child: PlayerFigure(focus: [PlayerMark.feet, PlayerMark.head]),
      ),
      locale: _fr,
    );

    expect(_legend(1), findsOneWidget);
    expect(_legend(3), findsOneWidget);
    for (final n in [2, 4, 5, 6]) {
      expect(_legend(n), findsNothing);
    }
    Opacity opacityOf(int n) => tester.widget<Opacity>(
      find.ancestor(of: _badge(n), matching: find.byType(Opacity)).first,
    );
    expect(opacityOf(1).opacity, 1);
    expect(opacityOf(2).opacity, lessThan(1));
  });

  testWidgets('draws only the top view, without the forearm', (tester) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(child: PlayerFigure(view: PlayerView.top)),
      locale: _fr,
    );

    expect(find.byKey(const ValueKey('player-figure-side')), findsNothing);
    expect(find.byKey(const ValueKey('player-figure-top')), findsOneWidget);
    expect(_legend(4), findsNothing);
    expect(_badge(4), findsNothing);
    for (final n in [1, 2, 3, 5, 6]) {
      expect(_legend(n), findsOneWidget);
    }
  });

  testWidgets('puts the two views side by side on a wide screen', (
    tester,
  ) async {
    await _size(tester, 1000);
    await pumpUi(
      tester,
      const SingleChildScrollView(child: PlayerFigure(view: PlayerView.both)),
    );

    final side = tester.getTopLeft(
      find.byKey(const ValueKey('player-figure-side')),
    );
    final top = tester.getTopLeft(
      find.byKey(const ValueKey('player-figure-top')),
    );

    expect(top.dx, greaterThan(side.dx));
    expect(top.dy, side.dy);
  });

  testWidgets('stacks the two views on a narrow screen', (tester) async {
    await _size(tester, 360);
    await pumpUi(
      tester,
      const SingleChildScrollView(child: PlayerFigure(view: PlayerView.both)),
    );

    final side = tester.getRect(
      find.byKey(const ValueKey('player-figure-side')),
    );
    final top = tester.getRect(find.byKey(const ValueKey('player-figure-top')));

    expect(top.top, greaterThanOrEqualTo(side.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('says where the head goes and which eye leads', (tester) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(
        child: PlayerFigure(
          view: PlayerView.top,
          headCase: HeadCase.leftEyeOverCue,
          leadEye: LeadEye.left,
        ),
      ),
      locale: _fr,
    );

    expect(
      find.text("Cas 3 : l'œil gauche au-dessus de la queue"),
      findsOneWidget,
    );
    expect(
      find.text("Œil directeur (marqué d'une cible) : l'œil gauche"),
      findsOneWidget,
    );
  });

  testWidgets('marks the eye of the head case as the lead eye', (tester) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(
        child: PlayerFigure(
          view: PlayerView.top,
          focus: [PlayerMark.head],
          headCase: HeadCase.rightEyeOverCue,
        ),
      ),
    );

    expect(
      find.text('Lead eye (marked with a target): the right eye'),
      findsOneWidget,
    );
  });

  testWidgets('marks no eye when the cue is between the two eyes', (
    tester,
  ) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(
        child: PlayerFigure(
          view: PlayerView.top,
          headCase: HeadCase.cueBetweenEyes,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('player-lead-eye')), findsNothing);
    expect(find.textContaining('Case 2'), findsOneWidget);
  });

  testWidgets('does not mention a head case without one', (tester) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(child: PlayerFigure(view: PlayerView.top)),
      locale: _fr,
    );

    expect(find.textContaining('Cas 1'), findsNothing);
    expect(find.byKey(const ValueKey('player-head-case')), findsNothing);
  });

  testWidgets('writes where the bridge hand rests', (tester) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(child: PlayerFigure()),
      locale: _fr,
    );
    expect(
      find.text('Main de chevalet : sur le cadre, le rail de la table'),
      findsOneWidget,
    );

    await pumpUi(
      tester,
      const SingleChildScrollView(
        child: PlayerFigure(bridge: CueBridge.surface),
      ),
      locale: _fr,
    );
    expect(find.text('Main de chevalet : à plat sur le tapis'), findsOneWidget);
  });

  testWidgets('is spoken once, with the view and the marks, in French', (
    tester,
  ) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(child: PlayerFigure(focus: [PlayerMark.cue])),
      locale: _fr,
    );

    expect(
      find.bySemanticsLabel(
        "Figure schématique d'un joueur droitier, vue de profil, billes non "
        "à l'échelle. Repères : 6. Queue : dans l'axe de la visée, vers le "
        'centre de la blanche',
      ),
      findsOneWidget,
    );
  });

  testWidgets('is spoken in English', (tester) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(
        child: PlayerFigure(view: PlayerView.top, focus: [PlayerMark.head]),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Schematic figure of a right-handed player, view from above, balls '
        'not to scale. Marks: 3. Head: in line with the cue, the lead eye '
        'above it',
      ),
      findsOneWidget,
    );
  });

  testWidgets('writes every text at 14 or more, for a projection', (
    tester,
  ) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(
        child: PlayerFigure(
          view: PlayerView.both,
          headCase: HeadCase.cueBetweenEyes,
        ),
      ),
    );

    final texts = tester.elementList(find.byType(Text)).toList();
    expect(texts, isNotEmpty);
    for (final element in texts) {
      expect(_effectiveSize(element), greaterThanOrEqualTo(14));
    }
  });

  testWidgets('does not overflow on a narrow screen at 200 % text', (
    tester,
  ) async {
    await _size(tester, 320, 640);
    await pumpUi(
      tester,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: SingleChildScrollView(
          child: PlayerFigure(
            view: PlayerView.both,
            headCase: HeadCase.rightEyeOverCue,
            bridge: CueBridge.surface,
          ),
        ),
      ),
      locale: _fr,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('is drawn in the dark theme', (tester) async {
    await _size(tester, 400);
    await pumpUi(
      tester,
      const SingleChildScrollView(child: PlayerFigure(view: PlayerView.both)),
      theme: ThemeData.dark(),
    );

    expect(tester.takeException(), isNull);
  });
}
