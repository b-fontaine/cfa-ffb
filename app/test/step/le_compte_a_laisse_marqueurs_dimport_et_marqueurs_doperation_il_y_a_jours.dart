import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> leCompteALaisseMarqueursDimportEtMarqueursDoperationIlYAJours(
  WidgetTester tester,
  String name,
  num imports,
  num operations,
  num daysAgo,
) async {
  StaleMarkersWorld.current.seed(
    name,
    imports: imports.toInt(),
    operations: operations.toInt(),
    daysAgo: daysAgo.toInt(),
  );
}
