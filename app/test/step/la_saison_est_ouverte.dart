import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';

/// Usage: la saison {'2026-2027'} est ouverte
Future<void> laSaisonEstOuverte(WidgetTester tester, String label) async {
  final season = await ClosureOps.season(label);
  expect(season.isClosed, isFalse);
}
