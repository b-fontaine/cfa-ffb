import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> lesPassagesDuClubSontRelusDansLordreDuFichier(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  expect(await world.attemptIds(), [
    for (final attempt in world.backup!.snapshot.attempts) attempt.id.value,
  ]);
}
