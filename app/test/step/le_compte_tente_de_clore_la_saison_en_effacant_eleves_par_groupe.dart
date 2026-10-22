import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leCompteTenteDeCloreLaSaisonEnEffacantElevesParGroupe(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.toErase = world.seeded!.firstOfEach(count.toInt());
  await world.close();
}
