import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the group {'Children group'} has {2} recorded sessions on
/// {'2026-10-12'}
///
/// Lit le dépôt : nombre de saisies du groupe ce jour-là.
Future<void> theGroupHasRecordedSessionsOn(
  WidgetTester tester,
  String groupName,
  num count,
  String date,
) async {
  final groups = await tester.runAsync(() => getIt<GroupRepository>().all());
  final group = groups!.firstWhere((candidate) => candidate.name == groupName);
  final records = await tester.runAsync(
    () => getIt<SessionRecordRepository>().forGroup(group.id),
  );
  final day = DateTime.parse(date);
  final onDay = [
    for (final record in records!)
      if (record.date.isSameDayAs(day)) record,
  ];
  expect(onDay, hasLength(count.toInt()), reason: 'saisies : $records');
}
