import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance saisie du groupe {'Jeunes'} le {'2026-10-19'} note la
/// séance du catalogue {'demi-bille-2'}
Future<void> laSeanceSaisieDuGroupeLeNoteLaSeanceDuCatalogue(
  WidgetTester tester,
  String group,
  String date,
  String sheetId,
) async {
  final day = TrackingWorld.date(date);
  final sessions = await getIt<SessionRecordRepository>().forGroup(
    TrackingWorld.groupId(group),
  );
  final session = sessions.singleWhere((s) => s.date.isSameDayAs(day));
  expect(session.sheetId?.value, sheetId);
}
