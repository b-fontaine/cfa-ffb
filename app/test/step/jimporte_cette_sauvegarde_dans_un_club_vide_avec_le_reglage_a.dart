import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage:
///   j'importe cette sauvegarde
///   dans un club vide avec le réglage {'seuil alerte'} à {9}
Future<void> jimporteCetteSauvegardeDansUnClubVideAvecLeReglageA(
  WidgetTester tester,
  String name,
  num value,
) async {
  final world = TrackingWorld.current;
  await world.importIntoEmptyClub(
    tester,
    world.backupWithSetting(name, value.toInt()),
  );
}
