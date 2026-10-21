import 'package:flutter_test/flutter_test.dart';

import '../support/local_data_world.dart';
import '../support/realistic_backup.dart';

/// Usage:
/// the club build keeps local data of {2} groups, {3} students per group
/// and {3} sessions per group
Future<void>
theClubBuildKeepsLocalDataOfGroupsStudentsPerGroupAndSessionsPerGroup(
  WidgetTester tester,
  num groups,
  num students,
  num sessions,
) => LocalDataWorld.keep(
  tester,
  RealisticBackup(
    groups: groups.toInt(),
    studentsPerGroup: students.toInt(),
    sessionsPerGroup: sessions.toInt(),
  ),
);
