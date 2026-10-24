import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> aucuneListeDesMarqueursDoperationNaEteDemandee(
  WidgetTester tester,
) async {
  final listed = OwnMarkersWorld.current.rules.listed;
  expect(listed, isNotEmpty);
  expect(listed.where((c) => c.endsWith('/operations')), isEmpty);
}
