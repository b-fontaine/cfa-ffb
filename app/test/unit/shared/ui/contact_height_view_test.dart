import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/contact_height_view.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

// Valeurs calculées à la main (plan « tailles et illustrations » § 2.4, 3.4) :
// r_c = 24,0 mm, r_o = 25,4 mm, s = 49,4 mm ; phi = asin(1,4 / 49,4)
// = 1,6240 deg ; x10 = 16,240 deg ; sin = 0,279659 ; r_o' = 42,635 mm.

const _view = Center(child: SizedBox(width: 480, child: ContactHeightView()));

Finder _balls() => find.byType(BilliardBall);

void main() {
  testWidgets('draws the cue ball and an object ball, the cue ball smaller', (
    tester,
  ) async {
    await pumpUi(tester, _view);

    expect(_balls(), findsNWidgets(2));
    final cue = tester.widget<BilliardBall>(_balls().first);
    final object = tester.widget<BilliardBall>(_balls().last);
    expect(cue.kind, BallKind.white);
    expect(object.kind, BallKind.red);
    final white = tester.getSize(_balls().first).width;
    final red = tester.getSize(_balls().last).width;
    expect(white, lessThan(red));
    // Écart exagéré par le rapport 24,0 / 42,6351 (inclinaison x10).
    expect(white / red, closeTo(24.0 / 42.6351, 1e-4));
  });

  testWidgets('the balls touch: centre distance is r_c + r_o', (tester) async {
    await pumpUi(tester, _view);

    final white = tester.getSize(_balls().first).width / 2;
    final red = tester.getSize(_balls().last).width / 2;
    final distance =
        (tester.getCenter(_balls().last) - tester.getCenter(_balls().first))
            .distance;
    expect(distance, closeTo(white + red, 1e-6));
  });

  testWidgets('the centre line is tilted 16.24 degrees (10 x 1.624)', (
    tester,
  ) async {
    await pumpUi(tester, _view);

    final delta =
        tester.getCenter(_balls().first) - tester.getCenter(_balls().last);
    // Le centre de la bille de but est plus haut : dy > 0 de la blanche vers
    // elle, donc l'angle de la droite des centres avec l'horizontale.
    final tilt = math.atan2(delta.dy.abs(), delta.dx.abs()) * 180 / math.pi;
    expect(tilt, closeTo(16.2398, 1e-2));
  });

  testWidgets('both balls rest on the same cloth line', (tester) async {
    await pumpUi(tester, _view);

    final white = tester.getRect(_balls().first);
    final red = tester.getRect(_balls().last);
    expect(white.bottom, closeTo(red.bottom, 1e-6));
  });

  testWidgets('marks the contact above the equator of the cue ball', (
    tester,
  ) async {
    await pumpUi(tester, _view);

    final cueCentre = tester.getCenter(_balls().first);
    final cueRadius = tester.getSize(_balls().first).width / 2;
    final contact = tester.getCenter(
      find.byKey(const ValueKey('contact-height-contact')),
    );
    // Hauteur au-dessus de l'équateur : r_c x sin(16,24 deg) = 0,279659 r_c.
    expect(cueCentre.dy - contact.dy, closeTo(0.279659 * cueRadius, 1e-3));
    // Le contact est sur le bord de la blanche.
    expect((contact - cueCentre).distance, closeTo(cueRadius, 1e-6));
  });

  testWidgets('says that the tilt is exaggerated, in both languages', (
    tester,
  ) async {
    await pumpUi(tester, _view, locale: const Locale('fr'));
    expect(find.textContaining('Inclinaison exagérée ×10'), findsOneWidget);
    expect(find.textContaining('48,0 mm'), findsOneWidget);
    expect(find.textContaining('50,8 mm'), findsOneWidget);
    expect(find.textContaining('0,68 mm'), findsOneWidget);

    await pumpUi(tester, _view);
    expect(find.textContaining('Tilt exaggerated ×10'), findsOneWidget);
    expect(find.textContaining('48.0 mm'), findsOneWidget);
    expect(find.textContaining('0.68 mm'), findsOneWidget);
  });

  testWidgets('speaks the exaggeration and the sheet no. 4 wording', (
    tester,
  ) async {
    await pumpUi(tester, _view, locale: const Locale('fr'));

    expect(
      find.bySemanticsLabel(
        RegExp(
          "^Hauteur du contact.*légèrement au-dessus de l'équateur de la "
          'blanche.*exagérée ×10',
        ),
      ),
      findsOneWidget,
    );

    await pumpUi(tester, _view);
    expect(
      find.bySemanticsLabel(
        RegExp(
          "^Contact height.*slightly above the cue ball's equator.*"
          'exaggerated ×10',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('names the equator and the contact in a legend', (tester) async {
    await pumpUi(tester, _view, locale: const Locale('fr'));

    expect(find.text('Équateur de la blanche'), findsOneWidget);
    expect(find.text('Point de contact'), findsOneWidget);
  });

  testWidgets('writes every label at 16 px or more', (tester) async {
    await pumpUi(tester, _view);

    for (final element in find.byType(RichText).evaluate()) {
      final size = (element.widget as RichText).text.style?.fontSize;
      if (size != null) expect(size, greaterThanOrEqualTo(16));
    }
  });

  testWidgets('legend labels do not overlap each other', (tester) async {
    await pumpUi(tester, _view, locale: const Locale('fr'));

    final a = tester.getRect(find.text('Équateur de la blanche'));
    final b = tester.getRect(find.text('Point de contact'));
    expect(a.overlaps(b), isFalse);
  });

  testWidgets('is painted in the dark theme without error', (tester) async {
    await pumpUi(tester, _view, theme: AppTheme.dark());

    expect(tester.takeException(), isNull);
    expect(_balls(), findsNWidgets(2));
  });
}
