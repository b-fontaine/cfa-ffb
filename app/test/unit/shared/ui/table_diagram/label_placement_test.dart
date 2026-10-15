import 'dart:ui';

import 'package:billard_cfa/shared/ui/table_diagram/label_placement.dart';
import 'package:flutter_test/flutter_test.dart';

/// Distance du centre du disque [disc] au rectangle [rect] (0 s'il est dedans).
double _distanceToDisc(Rect rect, LabelDisc disc) {
  final nearest = Offset(
    disc.center.dx.clamp(rect.left, rect.right),
    disc.center.dy.clamp(rect.top, rect.bottom),
  );
  return (nearest - disc.center).distance;
}

void main() {
  const bounds = Rect.fromLTWH(0, 0, 400, 200);
  const size = Size(20, 12);
  const anchor = Offset(200, 100);
  const request = LabelRequest(anchor: anchor, size: size, anchorRadius: 10);

  // Distance de l'anneau 0 : rayon 10 + écart 2 ; centre d'un emplacement :
  // (dx * (12 + 10), dy * (12 + 6)) à partir de l'ancrage.
  Rect around(double dx, double dy, {double ring = 0}) {
    final distance = 12 + ring * size.height;
    return Rect.fromCenter(
      center:
          anchor +
          Offset(
            dx * (distance + size.width / 2),
            dy * (distance + size.height / 2),
          ),
      width: size.width,
      height: size.height,
    );
  }

  group('placeLabels', () {
    test('takes the first slot (north east) when nothing is in the way', () {
      final result = placeLabels(labels: [request], bounds: bounds).single;

      expect(result.crowded, isFalse);
      expect(result.rect, around(1, -1));
    });

    test('returns nothing for no label', () {
      expect(placeLabels(labels: const [], bounds: bounds), isEmpty);
    });

    test('moves to the next slot (east) when a path crosses the first', () {
      final result = placeLabels(
        labels: [request],
        bounds: bounds,
        paths: [
          [around(1, -1).centerLeft, around(1, -1).centerRight],
        ],
      ).single;

      expect(result.crowded, isFalse);
      expect(result.rect, around(1, 0));
    });

    test('tries the eight compass slots in a fixed order', () {
      // Un repère au centre de chaque emplacement déjà essayé le bloque.
      const order = [
        (1.0, -1.0), // nord-est
        (1.0, 0.0), // est
        (1.0, 1.0), // sud-est
        (-1.0, -1.0), // nord-ouest
        (-1.0, 0.0), // ouest
        (-1.0, 1.0), // sud-ouest
        (0.0, -1.0), // nord
        (0.0, 1.0), // sud
      ];
      for (var i = 0; i < order.length; i++) {
        final result = placeLabels(
          labels: [request],
          bounds: bounds,
          paths: [
            for (final (dx, dy) in order.take(i)) [around(dx, dy).center],
          ],
        ).single;

        expect(
          result.rect,
          around(order[i].$1, order[i].$2),
          reason: 'rang $i',
        );
        expect(result.crowded, isFalse);
      }
    });

    test('tries the intermediate slots once the compass ones are blocked', () {
      final result = placeLabels(
        labels: [request],
        bounds: bounds,
        paths: [
          for (final (dx, dy) in [
            (1.0, -1.0),
            (1.0, 0.0),
            (1.0, 1.0),
            (-1.0, -1.0),
            (-1.0, 0.0),
            (-1.0, 1.0),
            (0.0, -1.0),
            (0.0, 1.0),
          ])
            [around(dx, dy).center],
        ],
      ).single;

      // Le repère du nord tombe aussi dans le nord-nord-est : le suivant, l'est
      // -nord-est, est le premier libre.
      expect(result.crowded, isFalse);
      expect(result.rect, around(1, -0.5));
    });

    test('moves to the next ring when the whole first ring is blocked', () {
      // Un disque centré sur l'ancrage recouvre les seize emplacements de
      // l'anneau 0 (au plus 15,6 px) mais aucun de l'anneau 1.
      final result = placeLabels(
        labels: [request],
        bounds: bounds,
        discs: const [LabelDisc(anchor, 17.5)],
      ).single;

      expect(result.crowded, isFalse);
      expect(result.rect, around(1, -1, ring: 1));
    });

    test('keeps a hair of clearance around a path', () {
      final slot = around(1, -1);
      Rect placeWithPathAt(double distanceToEdge) => placeLabels(
        labels: [request],
        bounds: bounds,
        paths: [
          [
            Offset(slot.left - distanceToEdge, slot.top),
            Offset(slot.left - distanceToEdge, slot.bottom),
          ],
        ],
      ).single.rect;

      // 0,5 px du bord : dans la marge de 1 px, l'emplacement est refusé.
      expect(placeWithPathAt(0.5), around(1, 0));
      // 1,5 px du bord : hors de la marge, l'emplacement est retenu.
      expect(placeWithPathAt(1.5), slot);
    });

    test('lets the first label keep its place and moves the second', () {
      final result = placeLabels(labels: [request, request], bounds: bounds);

      expect(result[0].rect, around(1, -1));
      expect(result[1].rect, around(1, 0));
      expect(result.every((place) => !place.crowded), isTrue);
    });

    test('keeps every label off the balls, each other and the edges', () {
      const labels = [
        request,
        LabelRequest(anchor: Offset(205, 100), size: size),
        LabelRequest(anchor: Offset(2, 2), size: size),
        LabelRequest(anchor: Offset(398, 198), size: size, anchorRadius: 10),
      ];
      const discs = [
        LabelDisc(Offset(230, 90), 12),
        LabelDisc(Offset(398, 198), 10),
      ];
      final result = placeLabels(labels: labels, bounds: bounds, discs: discs);

      for (final place in result) {
        expect(place.crowded, isFalse);
        for (final corner in [
          place.rect.topLeft,
          place.rect.bottomRight - const Offset(0.001, 0.001),
        ]) {
          expect(bounds.contains(corner), isTrue, reason: '$corner');
        }
        for (final disc in discs) {
          expect(
            _distanceToDisc(place.rect, disc),
            greaterThanOrEqualTo(disc.radius),
          );
        }
      }
      for (var i = 0; i < result.length; i++) {
        for (var j = i + 1; j < result.length; j++) {
          expect(result[i].rect.overlaps(result[j].rect), isFalse);
        }
      }
      // Près du coin bas droite, la position nord-est sortirait de la table :
      // l'étiquette glisse vers l'intérieur, au-dessus de la bille.
      expect(result[3].rect, const Rect.fromLTRB(380, 174, 400, 186));
    });

    test('slides a label back inside the table instead of cutting it', () {
      const corner = LabelRequest(anchor: Offset(2, 100), size: size);
      final result = placeLabels(labels: [corner], bounds: bounds).single;

      // Nord-est : à droite de l'ancrage, déjà dans la table.
      expect(result.rect.left, greaterThanOrEqualTo(bounds.left));
      expect(result.crowded, isFalse);

      // Plus large que la table, elle ne tient nulle part : elle est signalée.
      const huge = LabelRequest(anchor: Offset(200, 100), size: Size(500, 12));
      final wide = placeLabels(labels: [huge], bounds: bounds).single;
      expect(wide.crowded, isTrue);
    });

    test('stays clear of an obstacle already on the table', () {
      final result = placeLabels(
        labels: [request],
        bounds: bounds,
        obstacles: [around(1, -1)],
      ).single;

      expect(result.rect, around(1, 0));
    });

    test('falls back to the first slot when every position is blocked', () {
      // Un disque géant recouvre tous les emplacements au même coût.
      final result = placeLabels(
        labels: [request],
        bounds: bounds,
        discs: const [LabelDisc(anchor, 500)],
      ).single;

      expect(result.crowded, isTrue);
      expect(result.rect, around(1, -1));
    });

    test('falls back to the least annoying slot, a path before a ball', () {
      // Une bille sur chaque emplacement de l'anneau 0, sauf le sud où seul
      // passe un trait (sans marge, pour que les voisins ne le gênent pas) :
      // c'est le moins gênant, bien qu'il ne soit pas le premier essayé.
      final south = around(0, 1);
      final result = placeLabels(
        labels: [request],
        bounds: bounds,
        rings: 1,
        clearance: 0,
        discs: [
          for (final slot in LabelSlot.values)
            if (around(slot.dx, slot.dy) != south)
              LabelDisc(around(slot.dx, slot.dy).center, 0.5),
        ],
        paths: [
          [south.center],
        ],
      ).single;

      expect(result.crowded, isTrue);
      expect(result.rect, south);
    });

    test('is deterministic', () {
      final paths = [
        [const Offset(180, 80), const Offset(260, 80)],
        [const Offset(200, 20), const Offset(200, 180)],
      ];
      final a = placeLabels(labels: [request], bounds: bounds, paths: paths);
      final b = placeLabels(labels: [request], bounds: bounds, paths: paths);

      expect(a.single.rect, b.single.rect);
      expect(a.single.crowded, b.single.crowded);
    });
  });

  group('retractTipToCircle', () {
    const center = Offset(100, 0);

    test('stops the tip on the circle edge', () {
      final points = retractTipToCircle([Offset.zero, center], center, 10);

      expect(points.last, const Offset(90, 0));
    });

    test('leaves a path that does not end on the circle', () {
      final path = [Offset.zero, const Offset(50, 0)];

      expect(retractTipToCircle(path, center, 10), path);
    });

    test('leaves a last segment as long as the radius', () {
      final path = [const Offset(90, 0), center];

      expect(retractTipToCircle(path, center, 10), path);
    });

    test('leaves a last segment shorter than the radius', () {
      final path = [const Offset(91, 0), center];

      expect(retractTipToCircle(path, center, 10), path);
    });

    test('leaves a path of fewer than two points', () {
      expect(retractTipToCircle([Offset.zero], Offset.zero, 10), [Offset.zero]);
      expect(retractTipToCircle(const [], center, 10), isEmpty);
    });

    test('retracts a tip half a pixel from the centre, not further', () {
      final near = retractTipToCircle(
        [Offset.zero, const Offset(100.5, 0)],
        center,
        10,
      );
      final far = retractTipToCircle(
        [Offset.zero, const Offset(100.51, 0)],
        center,
        10,
      );

      expect(near.last, const Offset(90.5, 0));
      expect(far.last, const Offset(100.51, 0));
    });
  });

  group('placeBlock', () {
    const bounds = Rect.fromLTWH(0, 0, 400, 200);
    const size = Size(80, 60);

    // Un repère au centre de chaque coin le bloque.
    const bottomRight = Rect.fromLTWH(316, 136, 80, 60);
    const bottomLeft = Rect.fromLTWH(4, 136, 80, 60);
    const topRight = Rect.fromLTWH(316, 4, 80, 60);
    const topLeft = Rect.fromLTWH(4, 4, 80, 60);

    test('takes the bottom right corner when it is free', () {
      final rect = placeBlock(size: size, bounds: bounds)!;

      expect(rect, bottomRight);
    });

    test('moves to the bottom left corner when a path crosses the first', () {
      final rect = placeBlock(
        size: size,
        bounds: bounds,
        paths: [
          [const Offset(300, 190), const Offset(400, 190)],
        ],
      );

      expect(rect, bottomLeft);
    });

    test('avoids a disc and a label rectangle (top right corner)', () {
      final rect = placeBlock(
        size: size,
        bounds: bounds,
        discs: const [LabelDisc(Offset(360, 170), 15)],
        obstacles: const [Rect.fromLTWH(0, 140, 90, 60)],
      );

      expect(rect, topRight);
    });

    test('reaches the top left corner when the three others are blocked', () {
      final rect = placeBlock(
        size: size,
        bounds: bounds,
        obstacles: [bottomRight, bottomLeft, topRight],
      );

      expect(rect, topLeft);
    });

    test('slides along the bottom edge when the four corners are blocked', () {
      final rect = placeBlock(
        size: size,
        bounds: bounds,
        discs: [
          for (final corner in [bottomRight, bottomLeft, topRight, topLeft])
            LabelDisc(corner.center, 5),
        ],
      )!;

      // Un demi-bloc de décalage (40 px) bloque encore (le repère est dans le
      // bloc) ; deux demi-blocs (80 px) libèrent le bord bas.
      expect(rect, const Rect.fromLTWH(236, 136, 80, 60));
    });

    test('never covers a path, a disc or an obstacle', () {
      final rect = placeBlock(
        size: size,
        bounds: bounds,
        paths: [
          [const Offset(0, 150), const Offset(400, 150)],
        ],
      )!;

      expect(rect.top < 150 && rect.bottom > 150, isFalse);
    });

    test('returns null when no place on the table is free', () {
      final rect = placeBlock(
        size: size,
        bounds: bounds,
        discs: const [LabelDisc(Offset(200, 100), 1000)],
      );

      expect(rect, isNull);
    });
  });
}
