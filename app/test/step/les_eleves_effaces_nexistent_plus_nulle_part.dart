import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> lesElevesEffacesNexistentPlusNullePart(WidgetTester tester) async {
  final world = OperationsWorld.current;
  expect(world.toErase, isNotEmpty);
  for (final id in world.toErase) {
    expect(world.documentsAboutId(id.value), isEmpty, reason: id.value);
  }
}
