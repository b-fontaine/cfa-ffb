import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I see the billiard table
Future<void> iSeeTheBilliardTable(WidgetTester tester) async {
  expect(find.byType(BilliardTable), findsOneWidget);
  expect(
    DiagramWorld.describedAs('Billiard table, seen from above'),
    findsOneWidget,
  );
}
