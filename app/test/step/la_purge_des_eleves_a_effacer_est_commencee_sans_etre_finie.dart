import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laPurgeDesElevesAEffacerEstCommenceeSansEtreFinie(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  final total = world.toErase.length * world.spec!.attemptsPerStudent;
  final left = [
    for (final entry in world.server.documents.entries)
      if (entry.key.contains('/attempts/') &&
          world.toErase.any((id) => id.value == entry.value['studentId']))
        entry.key,
  ].length;
  expect(left, greaterThan(0));
  expect(left, lessThan(total));
}
