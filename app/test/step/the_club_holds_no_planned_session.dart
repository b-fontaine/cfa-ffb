import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: the club holds no planned session {'p-orphan'}
Future<void> theClubHoldsNoPlannedSession(
  WidgetTester tester,
  String id,
) async {
  expect(
    ImportWorld.current.server.documents.keys.where((p) => p.endsWith('/$id')),
    isEmpty,
  );
}
