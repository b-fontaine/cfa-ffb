import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> leCompteRetireSesMarqueursDuClub(
  WidgetTester tester,
  String name,
) async {
  await OwnMarkersWorld.current.removeOwn(name);
}
