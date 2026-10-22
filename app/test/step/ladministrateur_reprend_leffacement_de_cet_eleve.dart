import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> ladministrateurReprendLeffacementDeCetEleve(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  world.adminErasure = await world.admin!.erasure.erase(world.adminErased!);
}
