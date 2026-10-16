import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'importe à nouveau cette sauvegarde au format {1} sans acquittements
Future<void> jimporteANouveauCetteSauvegardeAuFormatSansAcquittements(
  WidgetTester tester,
  num version,
) async {
  final world = TrackingWorld.current;
  await world.importAgain(world.backupAtFormat(version.toInt()));
  TrackingWorld.valueOf(world.lastImport);
}
