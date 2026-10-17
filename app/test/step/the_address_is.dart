import 'package:flutter_test/flutter_test.dart';

import '../support/relaunch.dart';

/// Usage: the address is {'/backup'}
Future<void> theAddressIs(WidgetTester tester, String address) async {
  expect(currentAddress(tester), address);
}
