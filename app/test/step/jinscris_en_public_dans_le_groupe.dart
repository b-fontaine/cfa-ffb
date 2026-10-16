import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: j'inscris {'Zoé'} en public {'enfants'} dans le groupe {'Mercredi'}
Future<void> jinscrisEnPublicDansLeGroupe(
  WidgetTester tester,
  String student,
  String audience,
  String group,
) async {
  await GroupOps.enroll(student, audience, group: group);
  GroupOps.expectOk();
}
