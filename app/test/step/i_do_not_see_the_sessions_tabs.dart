import 'package:billard_cfa/shared/ui/app_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I do not see the sessions tabs
Future<void> iDoNotSeeTheSessionsTabs(WidgetTester tester) async {
  expect(find.byType(AppTabs), findsNothing);
}
