import 'package:flutter_test/flutter_test.dart';

import '../support/club_seed.dart';
import '../support/operations_world.dart';

Future<void> unClubSynchroniseDeGroupesDeElevesAyantChacunPassages(
  WidgetTester tester,
  num groups,
  num students,
  num attempts,
) async {
  final world = OperationsWorld.open();
  await world.seeding((w) async => w.seedDirector());
  await world.seedSpec(
    ClubSpec(
      groups: groups.toInt(),
      studentsPerGroup: students.toInt(),
      attemptsPerStudent: attempts.toInt(),
    ),
  );
}
