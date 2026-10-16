import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Léa'} a {1} autre alerte
Future<void> aAutreAlerte(
  WidgetTester tester,
  String student,
  num others,
) async {
  final line = TrackingWorld.current.watchList.lines.firstWhere(
    (line) => line.student.id == TrackingWorld.studentId(student),
  );
  expect(line.watched.otherAlerts, others.toInt());
}
