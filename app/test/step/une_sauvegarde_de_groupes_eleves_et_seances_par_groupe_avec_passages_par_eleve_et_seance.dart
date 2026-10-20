import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';
import '../support/realistic_backup.dart';

Future<void>
uneSauvegardeDeGroupesElevesEtSeancesParGroupeAvecPassagesParEleveEtSeance(
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
