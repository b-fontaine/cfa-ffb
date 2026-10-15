import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the quantity of ball diagram: {'half'} with the paths
/// after the contact
Future<void> iLookAtTheQuantityOfBallDiagramWithThePathsAfterTheContact(
  WidgetTester tester,
  String contact,
) {
  final fraction = switch (contact) {
    'full' => ContactFraction.full,
    'three-quarter' => ContactFraction.threeQuarter,
    'half' => ContactFraction.half,
    'quarter' => ContactFraction.quarter,
    'thin' => ContactFraction.thin,
    _ => throw ArgumentError('quantité de bille inconnue : $contact'),
  };
  return DiagramWorld.show(
    tester,
    BallContactDiagram(contact: fraction, showPaths: true),
  );
}
