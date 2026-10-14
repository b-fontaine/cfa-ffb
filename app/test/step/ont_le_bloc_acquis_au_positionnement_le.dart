import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> ontLeBlocAcquisAuPositionnementLe(
  WidgetTester tester,
  String students,
  String block,
  String date,
) async {
  for (final student in TrackingWorld.names(students)) {
    await TrackingWorld.current.markAcquired(
      student,
      block,
      TrackingWorld.date(date),
    );
  }
}
