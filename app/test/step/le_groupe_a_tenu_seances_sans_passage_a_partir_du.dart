import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le groupe {'Jeunes'} a tenu {4} séances sans passage à partir du
///   {'2026-10-01'}
Future<void> leGroupeATenuSeancesSansPassageAPartirDu(
  WidgetTester tester,
  String group,
  num count,
  String date,
) async {
  await TrackingWorld.current.holdSessions(
    group,
    count.toInt(),
    TrackingWorld.date(date),
  );
}
