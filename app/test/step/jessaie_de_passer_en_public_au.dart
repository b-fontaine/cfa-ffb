import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: j'essaie de passer {'Léa'} en public {'adultes'} au {'2026-10-12'}
Future<void> jessaieDePasserEnPublicAu(
  WidgetTester tester,
  String student,
  String audience,
  String date,
) async {
  await GroupOps.changeAudience(student, audience, date);
}
