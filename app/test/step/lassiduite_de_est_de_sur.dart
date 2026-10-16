import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'assiduité de {'Léa'} est de {2} sur {2}
Future<void> lassiduiteDeEstDeSur(
  WidgetTester tester,
  String student,
  num attended,
  num total,
) async {
  final column = TrackingWorld.current.grid.students.firstWhere(
    (s) => s.id == TrackingWorld.studentId(student),
  );
  expect(column.attendance.attended, attended.toInt());
  expect(column.attendance.total, total.toInt());
}
