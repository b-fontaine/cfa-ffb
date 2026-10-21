import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: the backup cites a sheet that the catalogue does not know
Future<void> theBackupCitesASheetThatTheCatalogueDoesNotKnow(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  expect(world.content, contains('demi-bille-1'));
  world.content = world.content!.replaceAll('demi-bille-1', 'fiche-inconnue');
}
