import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leMarqueurDoperationDuDirecteurEstAuLot(
  WidgetTester tester,
  num lot,
) async {
  final markers = OperationsWorld.current.markers();
  expect(markers, hasLength(1));
  final marker = markers.entries.single;
  expect(marker.key, endsWith('_u-dir'));
  expect(marker.value['done'], lot);
}
