import 'package:flutter_test/flutter_test.dart';

import '../support/relaunch.dart';
import '../support/ui_world.dart';

/// Usage: the address is the showcase of {'Léa'}
Future<void> theAddressIsTheShowcaseOf(WidgetTester tester, String name) async {
  final student = await UiWorld.studentNamed(name);
  expect(currentAddress(tester), '/students/${student.id.value}/show');
}
