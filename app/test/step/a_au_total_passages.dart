import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> aAuTotalPassages(
  WidgetTester tester,
  String name,
  num total,
) async {
  await OperationsWorld.current.seeding((w) async {
    final seeded = w.seededCounts[name]!;
    await w.seedAttempts(
      name,
      w.firstRecord[name]!,
      total.toInt() - seeded.attempts,
      offset: seeded.attempts,
    );
    w.seededCounts[name] = SeededCounts(
      attempts: total.toInt(),
      assessments: seeded.assessments,
      acknowledgements: seeded.acknowledgements,
      acquisitions: seeded.acquisitions,
      presences: seeded.presences,
    );
  });
}
