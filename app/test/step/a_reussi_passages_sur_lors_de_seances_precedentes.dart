import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> aReussiPassagesSurLorsDeSeancesPrecedentes(
  WidgetTester tester,
  String student,
  num count,
  String exercise,
) async {
  await TrackingWorld.current.seedPasses(
    student,
    TrackingWorld.exercise(exercise),
    count.toInt(),
    passed: true,
  );
}
