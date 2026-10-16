import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: je crée le groupe {'Mercredi'} de public {'enfants'}
Future<void> jeCreeLeGroupeDePublic(
  WidgetTester tester,
  String group,
  String audience,
) async {
  await GroupOps.create(group, audience);
}
