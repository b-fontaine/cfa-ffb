import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'ouvre la liste des élèves
Future<void> jouvreLaListeDesEleves(WidgetTester tester) async {
  await TrackingWorld.current.openClub();
}
