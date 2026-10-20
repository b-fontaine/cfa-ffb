import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leMarqueurDimportResteAuLot(WidgetTester tester, num lot) async {
  final marker = ImportWorld.current.marker();
  expect(marker, isNotNull);
  expect(marker!['done'], lot.toInt());
  expect(marker['state'], 'running');
}
