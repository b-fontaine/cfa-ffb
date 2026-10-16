import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: j'inscris {'Zoé'} en public {'enfants'}
Future<void> jinscrisEnPublic(
  WidgetTester tester,
  String student,
  String audience,
) async {
  await GroupOps.enroll(student, audience);
}
