import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage:
/// j'importe cette sauvegarde de format {1} sans réglages dans un club vide
Future<void> jimporteCetteSauvegardeDeFormatSansReglagesDansUnClubVide(
  WidgetTester tester,
  num version,
) async {
  final world = TrackingWorld.current;
  await world.importIntoEmptyClub(
    tester,
    world.backupWithoutSettings(version.toInt()),
  );
}
