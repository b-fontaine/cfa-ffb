import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

const _season = SeasonId('season');
const _group = GroupId('g1');
const _student = StudentId('s1');

Season _seasonOf({String id = 'season'}) => Season(
  id: SeasonId(id),
  label: '2026-2027',
  startDate: day(1),
  endDate: day(31),
);

SessionRecord _session({
  String id = 'x1',
  int dayOfMonth = 3,
  Audience audience = Audience.children,
  SeasonId season = _season,
  String? main,
  String? recall,
  String? sheet,
  Set<StudentId> present = const {_student},
}) => SessionRecord(
  id: SessionId(id),
  groupId: _group,
  seasonId: season,
  date: day(dayOfMonth),
  audience: audience,
  present: present,
  mainBlockId: main,
  recallBlockId: recall,
  sheetId: sheet == null ? null : SheetId(sheet),
);

BackupSnapshot _snapshot({
  List<SessionRecord>? sessions,
  List<ExerciseAttempt>? attempts,
  List<MaturityAssessment> assessments = const [],
  List<Season>? seasons,
  List<Session> planned = const [],
  List<BlockAcquisition> acquisitions = const [],
}) => BackupSnapshot(
  seasons: seasons ?? [_seasonOf()],
  students: [
    Student.enroll(
      id: _student,
      firstName: 'Léa',
      audience: Audience.children,
      since: day(1),
    ),
  ],
  groups: [
    Group(
      id: _group,
      seasonId: _season,
      name: 'Jeunes',
      audience: Audience.children,
    ),
  ],
  sessionRecords: sessions ?? [_session()],
  attempts: attempts ?? [attempt(ref('a', 1), potted: 3)],
  assessments: assessments,
  plannedSessions: planned,
  blockAcquisitions: acquisitions,
);

Future<InvariantCode?> _codeOf(BackupSnapshot snapshot) async {
  final world = DomainWorld();
  final rules = BackupRules(
    world.catalogueRepository,
    FixtureSessionSheetRepository(catalogueFixture()),
    RulesConfig(),
    FixedClock(DateTime(2026, 10, 12, 18)),
  );
  try {
    await rules.check(snapshot);
  } on InvariantViolation catch (violation) {
    return violation.code;
  }
  return null;
}

void main() {
  test('accepts a backup that respects the rules', () async {
    expect(await _codeOf(_snapshot()), isNull);
  });

  group('attempts', () {
    test('refuses an exercise outside the catalogue', () async {
      final snapshot = _snapshot(attempts: [attempt(ref('zzz', 1), potted: 3)]);

      expect(await _codeOf(snapshot), InvariantCode.backupInconsistent);
    });

    test('refuses an exercise number beyond its block', () async {
      final snapshot = _snapshot(attempts: [attempt(ref('a', 4), potted: 3)]);

      expect(await _codeOf(snapshot), InvariantCode.backupInconsistent);
    });

    test('refuses a student who was not present at the session', () async {
      final snapshot = _snapshot(
        sessions: [
          _session(present: const {StudentId('someone')}),
        ],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInconsistent);
    });

    test('accepts two passes with distinct indexes', () async {
      final snapshot = _snapshot(
        attempts: [
          attempt(ref('a', 1), potted: 3),
          attempt(ref('a', 1), potted: 4, id: 'a2', passIndex: 2),
        ],
      );

      expect(await _codeOf(snapshot), isNull);
    });

    test('refuses the same pass index twice', () async {
      final snapshot = _snapshot(
        attempts: [
          attempt(ref('a', 1), potted: 3),
          attempt(ref('a', 1), potted: 4, id: 'a2'),
        ],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInvalid);
    });

    test('refuses a pass index beyond the limit per session', () async {
      final snapshot = _snapshot(
        attempts: [attempt(ref('a', 1), potted: 3, passIndex: 3)],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInvalid);
    });

    test('counts passes per exercise, student and session', () async {
      final snapshot = _snapshot(
        sessions: [
          _session(),
          _session(id: 'x2', dayOfMonth: 4),
        ],
        attempts: [
          attempt(ref('a', 1), potted: 3),
          attempt(ref('a', 2), potted: 3, id: 'a2'),
          attempt(ref('a', 1), potted: 3, id: 'a3', session: 'x2'),
        ],
      );

      expect(await _codeOf(snapshot), isNull);
    });
  });

  group('sessions', () {
    test('refuses a date outside the season', () async {
      final snapshot = _snapshot(
        sessions: [
          SessionRecord(
            id: const SessionId('x1'),
            groupId: _group,
            seasonId: _season,
            date: DateTime(2027, 7),
            audience: Audience.children,
            present: const {_student},
          ),
        ],
        attempts: const [],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInvalid);
    });

    test('refuses an audience that differs from the group', () async {
      final snapshot = _snapshot(
        sessions: [_session(audience: Audience.adults)],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInvalid);
    });

    test('refuses a season that differs from the one of the group', () async {
      final snapshot = _snapshot(
        sessions: [_session(season: const SeasonId('other'))],
        seasons: [
          _seasonOf(),
          _seasonOf(id: 'other'),
        ],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInconsistent);
    });

    test('refuses an unknown notion block', () async {
      expect(
        await _codeOf(_snapshot(sessions: [_session(main: 'zzz')])),
        InvariantCode.backupInconsistent,
      );
      expect(
        await _codeOf(_snapshot(sessions: [_session(recall: 'zzz')])),
        InvariantCode.backupInconsistent,
      );
    });

    test('accepts known blocks and a session planned in the future', () async {
      final snapshot = _snapshot(
        sessions: [_session(dayOfMonth: 25, main: 'a', recall: 'b')],
        attempts: const [],
      );

      expect(await _codeOf(snapshot), isNull);
    });
  });

  group('planned sessions', () {
    Session plannedOn(
      String? sheet, {
      GroupId? group,
      Audience audience = Audience.children,
      int dayOfMonth = 5,
    }) => Session(
      id: 'p1',
      title: 'Demi-bille',
      date: day(dayOfMonth),
      audience: audience,
      groupId: group,
      sheetId: sheet == null ? null : SheetId(sheet),
    );

    test('accepts a free session and a known catalogue session', () async {
      final snapshot = _snapshot(
        planned: [
          plannedOn(null),
          plannedOn('demi-bille-2', group: _group),
        ],
      );

      expect(await _codeOf(snapshot), isNull);
    });

    test('refuses a catalogue session the catalogue does not know', () async {
      final snapshot = _snapshot(planned: [plannedOn('inconnue-9')]);

      expect(await _codeOf(snapshot), InvariantCode.backupUnknownSheet);
    });

    test('refuses an audience that differs from the group', () async {
      final snapshot = _snapshot(
        planned: [plannedOn(null, group: _group, audience: Audience.adults)],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInvalid);
    });

    test('accepts the first and the last day of the season', () async {
      for (final dayOfMonth in [1, 31]) {
        final snapshot = _snapshot(
          planned: [plannedOn(null, group: _group, dayOfMonth: dayOfMonth)],
        );

        expect(await _codeOf(snapshot), isNull, reason: 'jour $dayOfMonth');
      }
    });

    test('refuses the eve of the season and the day after its end', () async {
      // `day(0)` est le 30 septembre, `day(32)` le 1er novembre.
      for (final dayOfMonth in [0, 32]) {
        final snapshot = _snapshot(
          planned: [plannedOn(null, group: _group, dayOfMonth: dayOfMonth)],
        );

        expect(
          await _codeOf(snapshot),
          InvariantCode.backupInvalid,
          reason: 'jour $dayOfMonth',
        );
      }
    });

    test('refuses a group the backup does not hold', () async {
      final snapshot = _snapshot(
        planned: [plannedOn(null, group: const GroupId('ghost'))],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInconsistent);
    });
  });

  group('recorded sessions noting a catalogue session', () {
    test('accepts a known catalogue session', () async {
      final snapshot = _snapshot(sessions: [_session(sheet: 'demi-bille-1')]);

      expect(await _codeOf(snapshot), isNull);
    });

    test('refuses a catalogue session the catalogue does not know', () async {
      final snapshot = _snapshot(sessions: [_session(sheet: 'inconnue-9')]);

      expect(await _codeOf(snapshot), InvariantCode.backupUnknownSheet);
    });
  });

  group('assessments', () {
    MaturityAssessment assessmentOn(DateTime date) => MaturityAssessment(
      id: const AssessmentId('b1'),
      studentId: _student,
      date: date,
      concentration: 3,
      endurance: 3,
      frustration: 3,
    );

    test('refuses an assessment dated after today', () async {
      final snapshot = _snapshot(
        assessments: [assessmentOn(DateTime(2026, 10, 13))],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInvalid);
    });

    test('accepts an assessment dated today, whatever the hour', () async {
      final snapshot = _snapshot(
        assessments: [assessmentOn(DateTime(2026, 10, 12))],
      );

      expect(await _codeOf(snapshot), isNull);
    });
  });

  group('acquired blocks', () {
    BlockAcquisition acquiredOn(DateTime date, {String block = 'a'}) =>
        BlockAcquisition(
          id: const AcquisitionId('q1'),
          studentId: _student,
          blockId: block,
          date: date,
          source: AcquisitionSource.placement,
        );

    test('accepts a known block, today included', () async {
      final snapshot = _snapshot(
        acquisitions: [acquiredOn(DateTime(2026, 10, 12))],
      );

      expect(await _codeOf(snapshot), isNull);
    });

    test('refuses a block the catalogue does not know', () async {
      final snapshot = _snapshot(
        acquisitions: [acquiredOn(DateTime(2026, 10), block: 'zzz')],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupUnknownBlock);
    });

    test('refuses a date after today', () async {
      final snapshot = _snapshot(
        acquisitions: [acquiredOn(DateTime(2026, 10, 13))],
      );

      expect(await _codeOf(snapshot), InvariantCode.backupInvalid);
    });
  });
}
