import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/features/manage_settings/domain/save_settings.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the backup reminder delay is {7} days
Future<void> theBackupReminderDelayIsDays(WidgetTester tester, num days) async {
  await UiWorld.prepare(tester);
  final result = await getIt<SaveSettings>()(
    ClubSettings.defaults.copyWith(backupReminderDays: days.toInt()),
  );
  expect(result, isA<Ok<ClubSettings>>());
}
