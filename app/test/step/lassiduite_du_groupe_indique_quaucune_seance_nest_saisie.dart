import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'assiduité du groupe indique qu'aucune séance n'est saisie
Future<void> lassiduiteDuGroupeIndiqueQuaucuneSeanceNestSaisie(
  WidgetTester tester,
) async {
  final attendance = TrackingWorld.current.grid.attendance;
  expect(attendance.isEmpty, isTrue);
  expect(attendance.percent, isNull);
}
