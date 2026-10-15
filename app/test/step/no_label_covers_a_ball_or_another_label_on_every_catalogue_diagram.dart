import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: no label covers a ball or another label on every catalogue diagram
Future<void> noLabelCoversABallOrAnotherLabelOnEveryCatalogueDiagram(
  WidgetTester tester,
) async {
  var count = 0;
  final problems = await DiagramWorld.catalogueProblems(
    tester,
    (tester) => [
      for (final collision in DiagramWorld.labelCollisions(tester))
        if (!collision.contains(' x arrow ')) collision,
    ],
    // La présentation agrandit le texte de moitié : à la largeur d'un
    // téléphone, ce texte ne tient plus sur les schémas de dix billes ou plus.
    // Elle est vérifiée à la largeur d'une projection.
    modes: [false, if (DiagramWorld.width >= 900) true],
    onCount: (n) => count = n,
  );
  expect(count, greaterThan(100));
  expect(problems, isEmpty);
}
