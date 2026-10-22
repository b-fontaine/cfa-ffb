import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void>
leDirecteurClotLaSaisonSansSuiteNiSuppressionEnEffacantElevesParGroupe(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world
    ..toErase = world.seeded!.firstOfEach(count.toInt())
    ..prepareNext = false
    ..dropPlanned = false;
  await world.close();
}
