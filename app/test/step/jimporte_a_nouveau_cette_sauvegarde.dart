import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> jimporteANouveauCetteSauvegarde(WidgetTester tester) async {
  final world = TrackingWorld.current;
  await world.importAgain(world.backup);
}
