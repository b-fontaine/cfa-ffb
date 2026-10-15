import 'package:billard_cfa/shared/ui/app_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the sessions tab {'Catalogue'} is selected
Future<void> theSessionsTabIsSelected(WidgetTester tester, String label) async {
  final tabs = tester.widget<AppTabs>(find.byType(AppTabs));
  expect(tabs.labels[tabs.selectedIndex], label);
}
