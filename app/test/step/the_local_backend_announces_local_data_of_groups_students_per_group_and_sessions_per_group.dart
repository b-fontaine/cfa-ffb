import 'package:flutter_test/flutter_test.dart';

import '../support/local_data_world.dart';
import '../support/realistic_backup.dart';

/// Usage:
/// the local backend announces local data of {2} groups, {3} students per
/// group and {3} sessions per group
///
/// Le build local (drift) : la sonde annonce des données, mais le bandeau
/// n'a de sens que sous `firestore`.
Future<void>
theLocalBackendAnnouncesLocalDataOfGroupsStudentsPerGroupAndSessionsPerGroup(
  WidgetTester tester,
  num groups,
  num students,
  num sessions,
) => LocalDataWorld.announceUnderLocalBackend(
  tester,
  RealisticBackup(
    groups: groups.toInt(),
    studentsPerGroup: students.toInt(),
    sessionsPerGroup: sessions.toInt(),
  ),
);
