import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> larchiveEstEcriteEtLaSaisonEstClose(WidgetTester tester) async {
  final world = OperationsWorld.current;
  expect(
    world.server.documents.keys.where((p) => p.contains('/archives/')),
    isNotEmpty,
  );
  expect(world.doc('clubs/c1/seasons/season')!['closedOn'], isNotNull);
}
