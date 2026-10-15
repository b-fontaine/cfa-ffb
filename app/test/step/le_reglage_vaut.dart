import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/manage_settings/domain/load_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/settings_names.dart';
import '../support/tracking_world.dart';

/// Usage: le réglage {'passages requis'} vaut {5}
Future<void> leReglageVaut(WidgetTester tester, String name, num value) async {
  final settings = TrackingWorld.valueOf(await getIt<LoadSettings>()());
  expect(SettingsNames.read(settings, name), value);
}
