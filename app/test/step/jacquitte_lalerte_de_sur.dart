import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'acquitte l'alerte de {'Théo'} sur {'bille-fantome 1'}
Future<void> jacquitteLalerteDeSur(
  WidgetTester tester,
  String student,
  String exercise,
) async {
  await TrackingWorld.current.acknowledge(student, exercise);
}
