import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';

/// Usage: la clôture a effacé {1} élèves et reconduit {2}
Future<void> laClotureAEffaceElevesEtReconduit(
  WidgetTester tester,
  num erased,
  num kept,
) async {
  expect(ClosureOps.result.erased, erased.toInt());
  expect(ClosureOps.result.kept, kept.toInt());
}
