import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';

/// Usage: je prépare la clôture de la saison
Future<void> jePrepareLaClotureDeLaSaison(WidgetTester tester) async {
  await ClosureOps.prepare();
}
