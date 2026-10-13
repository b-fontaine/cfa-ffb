import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the quantity of ball diagram: {'half'} with the tip
/// {'left'}
Future<void> iLookAtTheQuantityOfBallDiagramWithTheTip(
  WidgetTester tester,
  String contact,
  String tip,
) {
  final fraction = switch (contact) {
    'full' => ContactFraction.full,
    'three-quarter' => ContactFraction.threeQuarter,
    'half' => ContactFraction.half,
    'quarter' => ContactFraction.quarter,
    'thin' => ContactFraction.thin,
    _ => throw ArgumentError('quantité de bille inconnue : $contact'),
  };
  final point = switch (tip) {
    'center' => TipPoint.center,
    'top' => TipPoint.top,
    'bottom' => TipPoint.bottom,
    'left' => TipPoint.left,
    'right' => TipPoint.right,
    _ => throw ArgumentError('point du procédé inconnu : $tip'),
  };
  return DiagramWorld.show(
    tester,
    BallContactDiagram(contact: fraction, tipPoint: point),
  );
}
