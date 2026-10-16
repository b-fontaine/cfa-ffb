import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: je supprime le groupe {'Mercredi'}
Future<void> jeSupprimeLeGroupe(WidgetTester tester, String group) async {
  await GroupOps.delete(group);
}
