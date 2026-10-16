import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';

/// Usage: l'effacement des passages d'un élève échouera
Future<void> leffacementDesPassagesDunEleveEchouera(WidgetTester tester) async {
  await ClosureOps.failNextErasure();
}
