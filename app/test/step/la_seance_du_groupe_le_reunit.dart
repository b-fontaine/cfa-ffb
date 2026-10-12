import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> laSeanceDuGroupeLeReunit(
  WidgetTester tester,
  String group,
  String date,
  String students,
) async {
  await TrackingWorld.current.openSession(
    group: group,
    on: TrackingWorld.date(date),
    present: TrackingWorld.names(students),
  );
}
