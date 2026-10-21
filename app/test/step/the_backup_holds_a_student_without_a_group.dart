import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';
import '../support/realistic_backup.dart';

/// Usage: the backup holds a student without a group
///
/// Un seul élève du fichier n'est dans aucun groupe, et son seul document est
/// un bloc acquis : rien ne dit où le rattacher, l'animateur doit choisir.
Future<void> theBackupHoldsAStudentWithoutAGroup(WidgetTester tester) async {
  final world = ImportWorld.current;
  final backup = world.backup!;
  final loose = backup.studentId(1, 1);
  final acquisition = RealisticBackup(history: true)
      .snapshot
      .blockAcquisitions
      .first
      .copyWith(studentId: loose);
  final snapshot = backup.snapshot.copyWith(
    groups: [
      for (final group in backup.snapshot.groups)
        group.copyWith(
          memberships: [
            for (final m in group.memberships)
              if (m.studentId != loose) m,
          ],
        ),
    ],
    attempts: [
      for (final a in backup.snapshot.attempts)
        if (a.studentId != loose) a,
    ],
    blockAcquisitions: [acquisition],
  );
  world.content = BackupCodec().encode(snapshot, exportedAt: backup.exportedAt);
}
