import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> aLeBlocAcquisAuPositionnementLe(
  WidgetTester tester,
  String student,
  String block,
  String date,
) => TrackingWorld.current.markAcquired(
  student,
  block,
  TrackingWorld.date(date),
);
