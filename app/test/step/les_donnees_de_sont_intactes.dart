import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> lesDonneesDeSontIntactes(WidgetTester tester, String name) async {
  final world = OperationsWorld.current;
  final id = OperationsWorld.idOf(name);
  final seeded = world.seededCounts[name]!;
  int count(String collection) => [
    for (final entry in world.server.documents.entries)
      if (entry.key.contains('/$collection/') && entry.value['studentId'] == id)
        entry.key,
  ].length;
  expect(count('attempts'), seeded.attempts);
  expect(count('assessments'), seeded.assessments);
  expect(count('acknowledgements'), seeded.acknowledgements);
  expect(count('acquisitions'), seeded.acquisitions);
  expect(count('memberships'), 1);
  expect(world.doc('clubs/c1/students/$id'), isNotNull);
  final records = [
    for (final entry in world.server.documents.entries)
      if (entry.key.contains('/records/')) entry.value,
  ];
  expect(records, isNotEmpty);
  for (final record in records) {
    expect(record['presentStudentIds'], contains(id));
  }
}
