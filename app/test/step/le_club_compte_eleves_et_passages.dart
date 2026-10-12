import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> leClubCompteElevesEtPassages(
  WidgetTester tester,
  num students,
  num attempts,
) async {
  final counts = await TrackingWorld.current.clubCounts();
  expect(counts.students, students);
  expect(counts.attempts, attempts);
}
