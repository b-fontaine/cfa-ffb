import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> jenregistrePourSurBillesReussiesSurTentatives(
  WidgetTester tester,
  String student,
  String exercise,
  num potted,
  num total,
) async {
  await TrackingWorld.current.record(
    student,
    TrackingWorld.exercise(exercise),
    potted: potted.toInt(),
    total: total.toInt(),
  );
}
