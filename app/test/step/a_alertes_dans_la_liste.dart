import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Léa'} a {1} alertes dans la liste
Future<void> aAlertesDansLaListe(
  WidgetTester tester,
  String student,
  num count,
) async {
  final members = [
    for (final group in TrackingWorld.current.club.groups) ...group.members,
    ...TrackingWorld.current.club.unassigned,
  ];
  final summary = members.firstWhere(
    (member) => member.student.id == TrackingWorld.studentId(student),
    orElse: () => fail("$student n'est pas dans la liste"),
  );
  expect(summary.alertCount, count.toInt());
}
