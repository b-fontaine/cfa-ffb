import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';
import 'le_club_est_identique_a_celui_dun_import_complet.dart';

/// Usage: the club is identical to the one of a complete import
Future<void> theClubIsIdenticalToTheOneOfACompleteImport(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  world.decisions = world.createAll();
  await leClubEstIdentiqueACeluiDunImportComplet(tester);
}
