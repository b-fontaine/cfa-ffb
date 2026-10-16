import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je rétablis l'alerte de {'Léa'} sur {'posture 1'}
Future<void> jeRetablisLalerteDeSur(
  WidgetTester tester,
  String student,
  String exercise,
) async {
  await TrackingWorld.current.restore(student, exercise);
}
