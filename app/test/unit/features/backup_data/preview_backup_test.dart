import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/domain/preview_backup.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

void main() {
  final codec = BackupCodec();
  final world = DomainWorld();
  final preview = PreviewBackup(
    codec,
    BackupRules(
      world.catalogueRepository,
      FixtureSessionSheetRepository(catalogueFixture()),
      RulesConfig(),
      FixedClock(DateTime(2026, 10, 12)),
    ),
  );
  final exportedAt = DateTime.utc(2026, 10, 12);

  test('counts what a backup holds', () async {
    final content = codec.encode(
      BackupSnapshot(
        seasons: [
          Season(
            id: const SeasonId('s'),
            label: '2026-2027',
            startDate: DateTime(2026, 9),
            endDate: DateTime(2027, 6, 30),
          ),
        ],
        students: [
          Student.enroll(
            id: const StudentId('a'),
            firstName: 'Léa',
            audience: Audience.children,
            since: DateTime(2026, 9),
          ),
          Student.enroll(
            id: const StudentId('b'),
            firstName: 'Hugo',
            audience: Audience.adults,
            since: DateTime(2026, 9),
          ),
        ],
        blockAcquisitions: const [],
      ),
      exportedAt: exportedAt,
    );

    final summary = ok(await preview(content));

    expect(
      summary,
      const ImportSummary(
        seasons: 1,
        students: 2,
        groups: 0,
        sessionRecords: 0,
        attempts: 0,
        assessments: 0,
        plannedSessions: 0,
        blockAcquisitions: 0,
      ),
    );
  });

  test('refuses an unreadable file with the reason of the import', () async {
    expect(
      codeOf(await preview('pas du json')),
      InvariantCode.backupUnreadable,
    );
  });

  test('refuses an inconsistent file like the import would', () async {
    final content = codec.encode(
      BackupSnapshot(
        attempts: [attempt(ref('a', 1), potted: 3)],
        blockAcquisitions: const [],
      ),
      exportedAt: exportedAt,
    );

    expect(codeOf(await preview(content)), InvariantCode.backupInconsistent);
  });

  test('refuses a file that breaks a domain rule like the import', () async {
    final student = Student.enroll(
      id: const StudentId('s1'),
      firstName: 'Léa',
      audience: Audience.children,
      since: day(1),
    );
    final content = codec.encode(
      BackupSnapshot(
        seasons: [
          Season(
            id: const SeasonId('season'),
            label: '2026-2027',
            startDate: day(1),
            endDate: day(31),
          ),
        ],
        students: [student],
        groups: [
          Group(
            id: const GroupId('g1'),
            seasonId: const SeasonId('season'),
            name: 'Jeunes',
            audience: Audience.children,
          ),
        ],
        sessionRecords: [
          SessionRecord(
            id: const SessionId('x1'),
            groupId: const GroupId('g1'),
            seasonId: const SeasonId('season'),
            date: day(3),
            audience: Audience.children,
            present: {student.id},
          ),
        ],
        attempts: [attempt(ref('unknown', 1), potted: 3)],
        blockAcquisitions: const [],
      ),
      exportedAt: exportedAt,
    );

    expect(codeOf(await preview(content)), InvariantCode.backupInconsistent);
  });
}
