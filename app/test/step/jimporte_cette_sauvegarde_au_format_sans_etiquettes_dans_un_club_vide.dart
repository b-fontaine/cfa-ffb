import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'importe cette sauvegarde au format {4} sans étiquettes dans un
/// club vide
///
/// Seul le format 4 est possible ici : c'est le dernier sans étiquettes.
Future<void> jimporteCetteSauvegardeAuFormatSansEtiquettesDansUnClubVide(
  WidgetTester tester,
  num version,
) async {
  expect(version, 4, reason: 'le format 4 est le dernier sans étiquettes');
  final world = TrackingWorld.current;
  await world.importIntoEmptyClub(tester, world.backupAtFormat4WithoutTags());
  TrackingWorld.valueOf(world.lastImport);
}
