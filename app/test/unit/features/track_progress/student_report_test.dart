import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/track_progress/domain/attendance.dart';
import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/features/track_progress/domain/student_report.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

const _student = StudentId('s1');
const _other = StudentId('s2');

SessionRecord _session(
  String id,
  int dayOfMonth, {
  Set<StudentId> present = const {_student},
  String? main,
}) => SessionRecord(
  id: SessionId(id),
  groupId: const GroupId('g1'),
  seasonId: const SeasonId('season'),
  date: day(dayOfMonth),
  audience: Audience.children,
  present: present,
  mainBlockId: main,
);

void main() {
  final catalogue = buildCatalogue();
  final group = Group(
    id: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    name: 'Jeunes',
    audience: Audience.children,
    memberships: [
      Membership(studentId: _student, from: day(1)),
      Membership(studentId: _other, from: day(1)),
    ],
  );

  StudentReport derive({
    List<SessionRecord> sessions = const [],
    List<Group>? groups,
    List<BlockAcquisition> acquisitions = const [],
  }) {
    final attempts = [
      attempt(ref('a', 1), potted: 4, id: 'p1', dayOfMonth: 2),
      attempt(ref('a', 1), potted: 0, id: 'p2', dayOfMonth: 3, session: 'x2'),
    ];
    return StudentReport.derive(
      studentId: _student,
      progress: StudentProgress.derive(
        studentId: _student,
        attempts: attempts,
        acquisitions: acquisitions,
        rates: catalogue.rates,
        config: RulesConfig(),
      ),
      catalogue: catalogue,
      attempts: attempts,
      sessions: sessions,
      groups: groups ?? [group],
    );
  }

  test('counts the exercises and the blocks of the catalogue', () {
    final report = derive();

    expect(report.studentId, _student);
    expect(report.exerciseCount, 9);
    expect(report.validatedCount, 0);
    expect(report.blocks.map((b) => b.blockId), ['a', 'b', 'c']);
    expect(report.blocks.first.status, BlockStatus.inProgress);
    expect(report.activeAlerts, isEmpty);
  });

  test('only counts the sessions where the student was present', () {
    final report = derive(
      sessions: [
        _session('x1', 2, main: 'a'),
        _session('x2', 3, main: 'a', present: const {_other}),
        _session('x3', 4, main: 'b'),
      ],
    );

    expect(report.blocks[0].sessionsSpent, 1, reason: 'absent de x2');
    expect(report.blocks[1].sessionsSpent, 1);
    expect(report.attendance, const Attendance(attended: 2, total: 3));
  });

  test('has an empty attendance without any group session', () {
    expect(derive(groups: const []).attendance.isEmpty, isTrue);
  });

  test('counts the exercises acquired at placement in the total', () {
    final report = derive(acquisitions: [acquisition('b')]);

    expect(report.validatedCount, 3);
    expect(report.blocks[1].status, BlockStatus.acquiredAtPlacement);
    expect(report.blocks[1].validatedCount, 3);
    expect(report.blocks[1].acquiredOn, day(1));
  });

  test('loses only the exercise taken over by a recorded pass', () {
    final report = derive(acquisitions: [acquisition('a', day: 3)]);

    expect(report.validatedCount, 2, reason: 'a2 et a3 restent acquis');
    expect(report.blocks.first.resumedCount, 1);
    expect(report.blocks.first.acquiredOn, day(3));
    expect(report.blocks.first.validatedCount, 2);
  });
}
