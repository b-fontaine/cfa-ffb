import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: j'essaie de passer {'Léa'} en public {'adultes'} au {'2026-10-12'}
///   dans le groupe
///   {'Midi'}
Future<void> jessaieDePasserEnPublicAuDansLeGroupe(
  WidgetTester tester,
  String student,
  String audience,
  String date,
  String group,
) async {
  await GroupOps.changeAudience(student, audience, date, group: group);
  GroupOps.expectOk();
}
