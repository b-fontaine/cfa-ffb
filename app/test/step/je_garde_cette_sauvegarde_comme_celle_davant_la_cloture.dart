import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';
import '../support/tracking_world.dart';

/// Usage: je garde cette sauvegarde comme celle d'avant la clôture
Future<void> jeGardeCetteSauvegardeCommeCelleDavantLaCloture(
  WidgetTester tester,
) async {
  ClosureOps.beforeClosure = TrackingWorld.current.backup;
}
