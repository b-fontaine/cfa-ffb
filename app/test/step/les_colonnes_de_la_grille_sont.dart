import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: les colonnes de la grille sont {'Léa, Théo'}
Future<void> lesColonnesDeLaGrilleSont(
  WidgetTester tester,
  String students,
) async {
  expect([
    for (final student in TrackingWorld.current.grid.students)
      student.firstName,
  ], TrackingWorld.names(students));
}
