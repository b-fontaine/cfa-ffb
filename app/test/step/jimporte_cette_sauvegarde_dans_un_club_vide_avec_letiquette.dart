import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'importe cette sauvegarde dans un club vide avec l'étiquette
/// {'Léa a pleuré'}
Future<void> jimporteCetteSauvegardeDansUnClubVideAvecLetiquette(
  WidgetTester tester,
  String code,
) async {
  final world = TrackingWorld.current;
  await world.importIntoEmptyClub(tester, world.backupWithTagCode(code));
}
