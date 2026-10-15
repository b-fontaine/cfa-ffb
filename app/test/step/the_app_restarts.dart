import 'package:billard_cfa/app/app.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the app restarts
///
/// Les données (dépôts) survivent ; les règles courantes sont relues des
/// réglages persistés, comme au lancement (`RulesModule`).
Future<void> theAppRestarts(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  final base = RulesConfig();
  final stored = await tester.runAsync(
    () async => (await getIt<SettingsRepository>().load()).orDefaults(base),
  );
  getIt<RulesStore>().current = stored!.applyTo(base);
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}
