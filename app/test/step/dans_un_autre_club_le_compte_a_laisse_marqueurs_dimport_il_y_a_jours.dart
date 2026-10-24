import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> dansUnAutreClubLeCompteALaisseMarqueursDimportIlYAJours(
  WidgetTester tester,
  String name,
  num imports,
  num daysAgo,
) async {
  StaleMarkersWorld.current.seed(
    name,
    imports: imports.toInt(),
    operations: 0,
    daysAgo: daysAgo.toInt(),
    inClub: 'c2',
  );
}
