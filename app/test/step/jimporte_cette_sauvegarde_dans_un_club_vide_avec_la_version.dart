import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> jimporteCetteSauvegardeDansUnClubVideAvecLaVersion(
  WidgetTester tester,
  num version,
) async {
  final world = TrackingWorld.current;
  await world.importIntoEmptyClub(
    tester,
    world.backupWithVersion(version.toInt()),
  );
}
