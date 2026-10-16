import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: je renomme le groupe {'Jeunes'} en {'Débutants'}
Future<void> jeRenommeLeGroupeEn(
  WidgetTester tester,
  String group,
  String name,
) async {
  await GroupOps.rename(group, name);
  GroupOps.expectOk();
}
