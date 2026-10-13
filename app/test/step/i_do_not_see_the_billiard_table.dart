import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I do not see the billiard table
Future<void> iDoNotSeeTheBilliardTable(WidgetTester tester) async {
  expect(find.byType(BilliardTable), findsNothing);
}
