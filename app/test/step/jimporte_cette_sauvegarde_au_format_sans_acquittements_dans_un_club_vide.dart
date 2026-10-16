import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'importe cette sauvegarde au format {2} sans acquittements dans un
///   club vide
Future<void> jimporteCetteSauvegardeAuFormatSansAcquittementsDansUnClubVide(
  WidgetTester tester,
  num version,
) async {
  final world = TrackingWorld.current;
  await world.importIntoEmptyClub(
    tester,
    world.backupAtFormat(version.toInt()),
  );
  TrackingWorld.valueOf(world.lastImport);
}
