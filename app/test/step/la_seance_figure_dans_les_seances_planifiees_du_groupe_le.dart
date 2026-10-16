import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance {'posture-2'} figure dans les séances planifiées du
/// groupe {'Jeunes'} le {'2026-10-19'}
Future<void> laSeanceFigureDansLesSeancesPlanifieesDuGroupeLe(
  WidgetTester tester,
  String sheet,
  String group,
  String date,
) async {
  final planned = await getIt<SessionRepository>().getAll();
  expect(
    planned.where(
      (s) =>
          s.sheetId == SheetId(sheet) &&
          s.groupId == TrackingWorld.groupId(group) &&
          s.date == TrackingWorld.date(date),
    ),
    hasLength(1),
  );
}
