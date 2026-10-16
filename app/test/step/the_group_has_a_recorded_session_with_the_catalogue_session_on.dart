import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the group {'Children group'} has a recorded session with the
/// catalogue session {'posture-1'} on {'2026-10-12'}
///
/// Lit le dépôt : une saisie du groupe ce jour-là note bien cette séance du
/// catalogue (elle n'a pas été réécrite par une autre ouverture).
Future<void> theGroupHasARecordedSessionWithTheCatalogueSessionOn(
  WidgetTester tester,
  String groupName,
  String sheetId,
  String date,
) async {
  final groups = await tester.runAsync(() => getIt<GroupRepository>().all());
  final group = groups!.firstWhere((candidate) => candidate.name == groupName);
  final records = await tester.runAsync(
    () => getIt<SessionRecordRepository>().forGroup(group.id),
  );
  final day = DateTime.parse(date);
  final matching = [
    for (final record in records!)
      if (record.date.isSameDayAs(day) && record.sheetId == SheetId(sheetId))
        record,
  ];
  expect(matching, hasLength(1), reason: 'saisies : $records');
}
