import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the catalogue shows the journey failure
///
/// L'échec est dit sous le sélecteur ; la liste des séances reste affichée.
Future<void> theCatalogueShowsTheJourneyFailure(WidgetTester tester) async {
  expect(
    find.byKey(const ValueKey('catalogue-journey-failure')),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('sheet:posture-1')), findsOneWidget);
}
