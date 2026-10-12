import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void>
jimporteCetteSauvegardeDansUnClubVideAvecUnPassageSurUnExerciceInconnu(
  WidgetTester tester,
) async {
  final world = TrackingWorld.current;
  await world.importIntoEmptyClub(tester, world.backupWithUnknownExercise());
}
