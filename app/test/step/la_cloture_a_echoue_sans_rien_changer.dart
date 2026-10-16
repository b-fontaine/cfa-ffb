import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';

/// Usage: la clôture a échoué sans rien changer
Future<void> laClotureAEchoueSansRienChanger(WidgetTester tester) async {
  expect(ClosureOps.crash, isA<StateError>());
}
