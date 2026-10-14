import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'exercice de tête {'posture 1'} n'est pas dans la séance proposée
Future<void> lexerciceDeTeteNestPasDansLaSeanceProposee(
  WidgetTester tester,
  String exercise,
) async {
  final sheet = TrackingWorld.current.plan.sheet;
  expect(sheet?.head, TrackingWorld.exercise(exercise));
  expect(sheet?.headCovered, isFalse);
}
