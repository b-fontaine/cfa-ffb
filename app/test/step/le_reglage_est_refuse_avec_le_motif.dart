import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le réglage est refusé avec le motif {'invalidRules'}
Future<void> leReglageEstRefuseAvecLeMotif(
  WidgetTester tester,
  String code,
) async {
  final result = TrackingWorld.current.lastSettingsSave;
  expect(result, isA<Err<ClubSettings>>());
  final failure = (result as Err<ClubSettings>).failure;
  expect(failure, isA<InvariantViolation>());
  expect((failure as InvariantViolation).code.name, code);
}
