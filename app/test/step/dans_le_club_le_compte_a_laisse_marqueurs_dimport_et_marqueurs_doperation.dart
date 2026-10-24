import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> dansLeClubLeCompteALaisseMarqueursDimportEtMarqueursDoperation(
  WidgetTester tester,
  String name,
  num imports,
  num operations,
) async {
  OwnMarkersWorld.current.seed(
    name,
    imports: imports.toInt(),
    operations: operations.toInt(),
  );
}
