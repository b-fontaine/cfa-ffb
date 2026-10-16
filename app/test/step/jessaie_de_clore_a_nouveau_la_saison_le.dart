import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';

/// Usage: j'essaie de clore à nouveau la saison le {'2026-10-13'}
Future<void> jessaieDeCloreANouveauLaSaisonLe(
  WidgetTester tester,
  String date,
) async {
  await ClosureOps.close(date, '', expectOk: false);
}
