import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la prochaine séance est {'posture-1'} le {'2026-10-14'}
Future<void> laProchaineSeanceEstLe(
  WidgetTester tester,
  String sheet,
  String date,
) async {
  final next = TrackingWorld.current.upcoming.next;
  expect(next, isNotNull);
  expect(next!.session.sheetId, SheetId(sheet));
  expect(next.session.date, TrackingWorld.date(date));
}
