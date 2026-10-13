import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/ui/ghost_aim_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  const cue = math.Point<double>(1.84, 2.31);
  const object = math.Point<double>(5, 2);

  group('spec', () {
    test('puts the ghost ball two radii behind the object, on the pocket '
        'line', () {
      final spec = GhostAimDiagram.buildSpec(
        cue: cue,
        object: object,
        pocket: TablePocket.tr,
        ghostName: 'G',
      );

      // Poche tr = (8, 0) : direction (3, -2), longueur sqrt 13 ; la bille
      // fantôme est à 0,2 de la cible dans le sens opposé.
      final ghost = spec.ghosts.single;
      expect(ghost.role, DiagramGhostRole.impact);
      expect(ghost.at.x, closeTo(5 - 0.2 * 3 / math.sqrt(13), 1e-9));
      expect(ghost.at.y, closeTo(2 + 0.2 * 2 / math.sqrt(13), 1e-9));
    });

    test('draws the cue ball, the object ball and both lines', () {
      final spec = GhostAimDiagram.buildSpec(
        cue: cue,
        object: object,
        pocket: TablePocket.tr,
        ghostName: 'G',
      );

      expect(spec.balls.map((b) => b.color), [BallKind.white, BallKind.red]);
      expect(spec.balls.map((b) => b.at), [cue, object]);
      final aim = spec.arrows.singleWhere(
        (a) => a.kind == DiagramArrowKind.aim,
      );
      expect(aim.path.first, cue);
      expect(aim.path.last, spec.ghosts.single.at);
      final toPocket = spec.arrows.singleWhere(
        (a) => a.kind == DiagramArrowKind.object,
      );
      expect(toPocket.path, [object, const DiagramPoint(8, 0)]);
      expect(toPocket.pocket, DiagramPocket.tr);
    });

    test('names the ghost ball with an annotation next to it', () {
      final spec = GhostAimDiagram.buildSpec(
        cue: cue,
        object: object,
        pocket: TablePocket.bm,
        ghostName: 'Fantôme',
      );

      expect(spec.annotations.single.text, 'Fantôme');
      expect(spec.annotations.single.at, spec.ghosts.single.at);
      expect(spec.arrows.last.pocket, DiagramPocket.bm);
    });
  });

  group('widget', () {
    testWidgets('is spoken with the fraction and the pocket in French', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const GhostAimDiagram(
          cue: cue,
          object: object,
          pocket: TablePocket.tr,
          fraction: ContactFraction.half,
        ),
        locale: const Locale('fr'),
      );

      expect(
        find.bySemanticsLabel(
          'Bille fantôme, Demi-bille : la blanche vise le point où elle '
          'touche la bille de couleur pour l’envoyer dans la poche en haut à '
          'droite.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('is spoken in English and writes the ghost ball name', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const GhostAimDiagram(
          cue: cue,
          object: object,
          pocket: TablePocket.bm,
          fraction: ContactFraction.quarter,
        ),
      );

      expect(
        find.bySemanticsLabel(
          'Ghost ball, Quarter ball: the cue ball aims at the point where it '
          'touches the object ball to send it into the bottom middle pocket.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ghost ball'), findsOneWidget);
    });

    testWidgets('lets the table fill the width and does not overflow', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const Center(
          child: SizedBox(
            width: 160,
            child: GhostAimDiagram(
              cue: cue,
              object: object,
              pocket: TablePocket.tl,
              fraction: ContactFraction.thin,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
