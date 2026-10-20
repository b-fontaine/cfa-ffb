import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> laSauvegardeContientUneSeancePlanifieeSansGroupe(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  final backup = world.backup!;
  final withOrphan = backup.snapshot.copyWith(
    plannedSessions: [
      ...backup.snapshot.plannedSessions,
      Session(
        id: 'p-orphan',
        title: 'Séance sans groupe',
        date: DateTime(2026, 11, 5),
        audience: Audience.children,
      ),
    ],
  );
  world.content = BackupCodec().encode(
    withOrphan,
    exportedAt: backup.exportedAt,
  );
}
