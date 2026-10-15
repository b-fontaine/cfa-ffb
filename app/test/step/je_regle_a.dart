import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/manage_settings/domain/load_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/save_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/settings_names.dart';
import '../support/tracking_world.dart';

/// Usage: je règle {'délai rappel sauvegarde'} à {14}
Future<void> jeRegleA(WidgetTester tester, String name, num value) async {
  final world = TrackingWorld.current;
  final current = TrackingWorld.valueOf(await getIt<LoadSettings>()());
  world.lastSettingsSave = await getIt<SaveSettings>()(
    SettingsNames.write(current, name, value.toInt()),
  );
}
