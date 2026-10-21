import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';
import '../support/realistic_backup.dart';

/// Usage:
/// a backup of {2} groups, {6} students and {3} sessions per group with
/// {4} passes per student and session
Future<void>
aBackupOfGroupsStudentsAndSessionsPerGroupWithPassesPerStudentAndSession(
  WidgetTester tester,
  num groups,
  num students,
  num sessions,
  num attempts,
) async {
  final backup = RealisticBackup(
    groups: groups.toInt(),
    studentsPerGroup: students.toInt() ~/ groups.toInt(),
    sessionsPerGroup: sessions.toInt(),
    attemptsPerStudentSession: attempts.toInt(),
  );
  ImportWorld.current
    ..backup = backup
    ..content = backup.content;
}
