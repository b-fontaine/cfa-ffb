import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leDirecteurConfirmeLeRetablissementDeEleves(
  WidgetTester tester,
  num students,
) async {
  final world = ImportWorld.current;
  world.decisions = world.decisions.copyWith(
    restoreConfirmed: students.toInt(),
  );
  await world.prepare();
}
