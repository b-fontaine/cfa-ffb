import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';

/// Usage:
/// the menu of the group {'Groupe 1'} offers {'To choose, Match to: Jeudi'}
Future<void> theMenuOfTheGroupOffers(
  WidgetTester tester,
  String group,
  String options,
) async {
  final menu = ImportScreenWorld.groupMenu(group);
  final items = tester.widget<DropdownButton<int>>(menu).items!;
  expect([
    for (final item in items) (item.child as Text).data,
  ], options.split(', '));
}
