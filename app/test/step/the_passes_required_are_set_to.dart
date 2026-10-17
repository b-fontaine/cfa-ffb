import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the passes required are set to {6}
Future<void> thePassesRequiredAreSetTo(WidgetTester tester, int passes) async {
  await UiWorld.prepare(tester);
  getIt<RulesStore>().current = RulesConfig(passesRequired: passes);
}
