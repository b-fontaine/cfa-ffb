import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: je déplace {'Léa'} vers le groupe {'Mercredi'} le {'2026-10-12'}
Future<void> jeDeplaceVersLeGroupeLe(
  WidgetTester tester,
  String student,
  String group,
  String date,
) async {
  await GroupOps.move(student, group, date);
  GroupOps.expectOk();
}
