import 'package:billard_cfa/shared/ui/app_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the sessions tabs are {'Planned, Catalogue, Suggestion'}
Future<void> theSessionsTabsAre(WidgetTester tester, String labels) async {
  final tabs = tester.widget<AppTabs>(find.byType(AppTabs));
  expect(tabs.labels, labels.split(', '));
}
