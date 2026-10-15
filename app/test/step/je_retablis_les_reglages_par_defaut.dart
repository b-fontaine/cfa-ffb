import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/manage_settings/domain/reset_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je rétablis les réglages par défaut
Future<void> jeRetablisLesReglagesParDefaut(WidgetTester tester) async {
  TrackingWorld.valueOf(await getIt<ResetSettings>()());
}
