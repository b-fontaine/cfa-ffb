import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the opened session follows the catalogue session {'posture-1'}
Future<void> theOpenedSessionFollowsTheCatalogueSession(
  WidgetTester tester,
  String sheetId,
) async {
  final sessions = await getIt<SessionRecordRepository>().all();
  expect(sessions, hasLength(1));
  expect(sessions.single.sheetId, SheetId(sheetId));
}
