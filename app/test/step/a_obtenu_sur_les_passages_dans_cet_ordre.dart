import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> aObtenuSurLesPassagesDansCetOrdre(
  WidgetTester tester,
  String student,
  String exercise,
  String passes,
) async {
  for (final pass in passes.split(',')) {
    final parts = pass.trim().split('/');
    await TrackingWorld.current.seedPass(
      student,
      TrackingWorld.exercise(exercise),
      potted: int.parse(parts.first),
      total: int.parse(parts.last),
    );
  }
}
