import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';
import '../support/tracking_world.dart';

/// Usage: j'importe la sauvegarde d'avant la clôture
Future<void> jimporteLaSauvegardeDavantLaCloture(WidgetTester tester) async {
  await TrackingWorld.current.importAgain(ClosureOps.beforeClosure!);
}
