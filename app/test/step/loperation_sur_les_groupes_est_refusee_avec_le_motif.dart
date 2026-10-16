import 'package:flutter_test/flutter_test.dart';

import '../support/group_ops.dart';

/// Usage: l'opération sur les groupes est refusée avec le motif
///   {'groupNameTaken'}
Future<void> loperationSurLesGroupesEstRefuseeAvecLeMotif(
  WidgetTester tester,
  String code,
) async {
  GroupOps.expectRefused(code);
}
