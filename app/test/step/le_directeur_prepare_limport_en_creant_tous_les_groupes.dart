import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leDirecteurPrepareLimportEnCreantTousLesGroupes(
  WidgetTester tester,
) async {
  final world = ImportWorld.current..act(Role.director);
  world.decisions = world.createAll();
  await world.prepare();
}
