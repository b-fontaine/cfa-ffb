import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> leNettoyageEstInterrompuFauteDeReseau(WidgetTester tester) async {
  final world = OwnMarkersWorld.current;
  expect(world.removed, isNull);
  expect(world.failure?.code, ServiceFailureCode.unavailable);
}
