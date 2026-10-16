import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';

/// Usage: je clos la saison le {'2026-10-12'} en effaçant {'Hugo'}
Future<void> jeClosLaSaisonLeEnEffacant(
  WidgetTester tester,
  String date,
  String students,
) async {
  await ClosureOps.close(date, students);
}
