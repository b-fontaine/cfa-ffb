import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> aPassagesBilanAcquittementBlocAcquisEtPresences(
  WidgetTester tester,
  String name,
  num attempts,
  num assessments,
  num acknowledgements,
  num acquisitions,
  num presences,
) async {
  expect(presences, greaterThan(0), reason: 'les passages ont une séance');
  await OperationsWorld.current.seeding((w) async {
    final group = w.groupOfStudent[name]!;
    final present = [
      for (final other in w.studentNames)
        if (w.groupOfStudent[other] == group) other,
    ];
    for (var i = 1; i <= presences; i++) {
      final id = w.nextRecordId();
      await w.seedRecord(id, group, present, dayOfMonth: 4 + i);
      w.firstRecord.putIfAbsent(name, () => id);
    }
    await w.seedAttempts(name, w.firstRecord[name]!, attempts.toInt());
    for (var i = 0; i < assessments; i++) {
      await w.seedAssessment(name);
    }
    for (var i = 0; i < acquisitions; i++) {
      await w.seedAcquisition(name);
    }
    for (var i = 0; i < acknowledgements; i++) {
      await w.seedAcknowledgement(name);
    }
    w.seededCounts[name] = SeededCounts(
      attempts: attempts.toInt(),
      assessments: assessments.toInt(),
      acknowledgements: acknowledgements.toInt(),
      acquisitions: acquisitions.toInt(),
      presences: presences.toInt(),
    );
  });
}
