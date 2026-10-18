import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the passes required are set to {6}
Future<void> thePassesRequiredAreSetTo(WidgetTester tester, int passes) async {
  await UiWorld.prepare(tester);
  final rules = RulesConfig(passesRequired: passes);
  // Un réglage du club : enregistré, comme l'application le fait, pour que le
  // rechargement à l'activation du club le retrouve.
  await tester.runAsync(
    () => getIt<SettingsRepository>().save(ClubSettings.fromRules(rules)),
  );
  getIt<RulesStore>().current = rules;
}
