import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the group {'Children group'} has a planned session with the
/// catalogue session {'posture-2'} on {'2026-10-19'}
Future<void> theGroupHasAPlannedSessionWithTheCatalogueSessionOn(
  WidgetTester tester,
  String groupName,
  String sheetId,
  String date,
) async {
  final groups = await tester.runAsync(() => getIt<GroupRepository>().all());
  final group = groups!.firstWhere((candidate) => candidate.name == groupName);
  final sessions = await tester.runAsync(
    () => getIt<SessionRepository>().getAll(),
  );
  final day = DateTime.parse(date);
  final matching = [
    for (final session in sessions!)
      if (session.groupId == group.id &&
          session.sheetId == SheetId(sheetId) &&
          session.date.year == day.year &&
          session.date.month == day.month &&
          session.date.day == day.day)
        session,
  ];
  expect(matching, hasLength(1), reason: 'séances planifiées : $sessions');
}
