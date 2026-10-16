import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: le club ne compte pas l'élève {'Zoé'}
Future<void> leClubNeComptePasLeleve(
  WidgetTester tester,
  String student,
) async {
  expect(await GroupOps.studentNamed(student), isNull);
}
