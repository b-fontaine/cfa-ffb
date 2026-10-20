import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_integrity.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/realistic_backup.dart';

void main() {
  final backup = RealisticBackup(history: true);
  final snapshot = backup.snapshot;

  List<(ImportProblemCode, ImportCategory?)> problemsOf(BackupSnapshot file) =>
      [
        for (final p in const ImportIntegrity().check(file).build())
          (p.code, p.category),
      ];

  test('a coherent file has no problem', () {
    expect(const ImportIntegrity().check(snapshot).isEmpty, isTrue);
  });

  group('duplicates', () {
    test('every collection is checked', () {
      final doubled = snapshot.copyWith(
        seasons: [...snapshot.seasons, snapshot.seasons.first],
        students: [...snapshot.students, snapshot.students.first],
        groups: [...snapshot.groups, snapshot.groups.first],
        sessionRecords: [
          ...snapshot.sessionRecords,
          snapshot.sessionRecords.first,
        ],
        attempts: [...snapshot.attempts, snapshot.attempts.first],
        assessments: [...snapshot.assessments, snapshot.assessments.first],
        blockAcquisitions: [
          ...snapshot.blockAcquisitions,
          snapshot.blockAcquisitions.first,
        ],
        alertAcknowledgements: [
          ...snapshot.alertAcknowledgements!,
          snapshot.alertAcknowledgements!.first,
        ],
        plannedSessions: [
          ...snapshot.plannedSessions,
          snapshot.plannedSessions.first,
        ],
      );
      final duplicates = {
        for (final (code, category) in problemsOf(doubled))
          if (code == ImportProblemCode.duplicateId) category,
      };
      expect(duplicates, {
        ImportCategory.seasons,
        ImportCategory.students,
        ImportCategory.groups,
        ImportCategory.sessionRecords,
        ImportCategory.attempts,
        ImportCategory.assessments,
        ImportCategory.acquisitions,
        ImportCategory.acknowledgements,
        ImportCategory.plannedSessions,
        ImportCategory.memberships,
      });
    });

    test('counts every duplicate and keeps only the first identifiers', () {
      final attempts = [
        for (final a in snapshot.attempts.take(6)) ...[a, a],
      ];
      final problems = const ImportIntegrity()
          .check(snapshot.copyWith(attempts: attempts))
          .build()
          .where((p) => p.code == ImportProblemCode.duplicateId)
          .single;
      expect(problems.count, 6);
      expect(problems.sample, hasLength(ProblemCollector.sampleSize));
    });
  });

  group('references', () {
    test(
      'a group on an unknown season, a membership of an unknown student',
      () {
        final broken = snapshot.copyWith(
          groups: [
            snapshot.groups.first.copyWith(seasonId: const SeasonId('ghost')),
            snapshot.groups.last.copyWith(
              memberships: [
                Membership(
                  studentId: const StudentId('ghost'),
                  from: DateTime(2026, 9),
                ),
              ],
            ),
          ],
        );
        expect(
          problemsOf(broken),
          containsAll([
            (ImportProblemCode.danglingReference, ImportCategory.groups),
            (ImportProblemCode.danglingReference, ImportCategory.memberships),
          ]),
        );
      },
    );

    test('a record on an unknown group, another season, an absent student', () {
      SessionRecord record(
        SessionRecord r, {
        GroupId? group,
        SeasonId? season,
        Set<StudentId>? present,
      }) => r.copyWith(
        groupId: group ?? r.groupId,
        seasonId: season ?? r.seasonId,
        present: present ?? r.present,
      );
      final base = snapshot.sessionRecords.first;
      for (final broken in [
        record(base, group: const GroupId('ghost')),
        record(base, season: RealisticBackup.oldSeason),
        record(base, present: {...base.present, const StudentId('ghost')}),
      ]) {
        expect(
          problemsOf(snapshot.copyWith(sessionRecords: [broken])),
          contains((
            ImportProblemCode.danglingReference,
            ImportCategory.sessionRecords,
          )),
        );
      }
    });

    test(
      'an attempt without a session is an orphan, an absent student dangles',
      () {
        final attempt = snapshot.attempts.first;
        expect(
          problemsOf(
            snapshot.copyWith(
              attempts: [attempt.copyWith(sessionId: const SessionId('ghost'))],
            ),
          ),
          contains((ImportProblemCode.orphanAttempt, ImportCategory.attempts)),
        );
        final other = snapshot.students.last.id;
        expect(
          problemsOf(
            snapshot.copyWith(attempts: [attempt.copyWith(studentId: other)]),
          ),
          contains((
            ImportProblemCode.danglingReference,
            ImportCategory.attempts,
          )),
        );
      },
    );

    test('unknown student, unknown planned group, open-season archive', () {
      const ghost = StudentId('ghost');
      final broken = snapshot.copyWith(
        assessments: [snapshot.assessments.first.copyWith(studentId: ghost)],
        blockAcquisitions: [
          snapshot.blockAcquisitions.first.copyWith(studentId: ghost),
        ],
        alertAcknowledgements: [
          snapshot.alertAcknowledgements!.first.copyWith(studentId: ghost),
        ],
        plannedSessions: [
          snapshot.plannedSessions.first.copyWith(
            groupId: const GroupId('ghost'),
          ),
        ],
        seasonArchives: [
          snapshot.seasonArchives.first.copyWith(
            seasonId: RealisticBackup.season,
          ),
        ],
      );
      expect(
        {
          for (final (code, category) in problemsOf(broken))
            if (code == ImportProblemCode.danglingReference) category,
        },
        {
          ImportCategory.assessments,
          ImportCategory.acquisitions,
          ImportCategory.acknowledgements,
          ImportCategory.plannedSessions,
          ImportCategory.seasonArchives,
        },
      );
    });
  });

  group('the bounds of the domain and of the rules', () {
    test(
      'a group name, a title, a present list beyond the rules are refused',
      () {
        final tooMany = {
          for (var i = 0; i <= maxPresentStudents; i++) StudentId('s$i'),
        };
        final broken = snapshot.copyWith(
          groups: [
            snapshot.groups.first.copyWith(
              name: 'x' * (maxGroupNameLength + 1),
            ),
            snapshot.groups.last,
          ],
          plannedSessions: [
            snapshot.plannedSessions.first.copyWith(
              title: 'x' * (maxSessionTitleLength + 1),
            ),
          ],
          sessionRecords: [
            snapshot.sessionRecords.first.copyWith(present: tooMany),
          ],
        );
        expect(
          problemsOf(broken),
          containsAll([
            (ImportProblemCode.valueTooLong, ImportCategory.groups),
            (ImportProblemCode.valueTooLong, ImportCategory.plannedSessions),
            (ImportProblemCode.tooManyPresent, ImportCategory.sessionRecords),
          ]),
        );
      },
    );

    test('lengths count characters, like the rules, not UTF-16 units', () {
      final emoji = '😀' * maxGroupNameLength;
      expect(emoji.length, maxGroupNameLength * 2);
      final fine = snapshot.copyWith(
        groups: [
          snapshot.groups.first.copyWith(name: emoji),
          snapshot.groups.last,
        ],
      );
      expect(
        problemsOf(fine).where((p) => p.$1 == ImportProblemCode.valueTooLong),
        isEmpty,
      );
    });

    test(
      'identifiers: empty, long, slash, reserved, or an underscore in a group',
      () {
        final base = snapshot.students.first;
        for (final id in [
          '',
          'x' * (maxIdentifierLength + 1),
          'a/b',
          '.',
          '..',
          '__reserved__',
        ]) {
          expect(
            problemsOf(
              snapshot.copyWith(students: [base.copyWith(id: StudentId(id))]),
            ),
            contains((
              ImportProblemCode.badIdentifier,
              ImportCategory.students,
            )),
            reason: 'student id "$id"',
          );
        }
        expect(
          problemsOf(
            snapshot.copyWith(
              groups: [
                snapshot.groups.first.copyWith(id: const GroupId('g_1')),
                snapshot.groups.last,
              ],
            ),
          ),
          contains((ImportProblemCode.badIdentifier, ImportCategory.groups)),
        );
      },
    );

    test(
      'a reference longer than 64 characters in a data document is refused',
      () {
        final attempt = snapshot.attempts.first;
        final long = SessionId('x' * (maxIdentifierLength + 1));
        final record = snapshot.sessionRecords.first.copyWith(id: long);
        final broken = snapshot.copyWith(
          sessionRecords: [record],
          attempts: [attempt.copyWith(sessionId: long)],
        );
        expect(
          problemsOf(broken),
          contains((
            ImportProblemCode.badIdentifier,
            ImportCategory.sessionRecords,
          )),
        );
      },
    );

    test('a date the server would refuse is detected', () {
      final broken = snapshot.copyWith(
        attempts: [snapshot.attempts.first.copyWith(date: DateTime.utc(10000))],
      );
      expect(
        problemsOf(broken),
        contains((ImportProblemCode.badDate, ImportCategory.attempts)),
      );
      expect(
        problemsOf(
          snapshot.copyWith(
            attempts: [
              snapshot.attempts.first.copyWith(
                date: DateTime.utc(2026, 10, 3, 8, 30, 1, 123, 456),
              ),
            ],
          ),
        ),
        isNot(contains((ImportProblemCode.badDate, ImportCategory.attempts))),
      );
    });

    test('an exercise number beyond the rules is refused', () {
      final attempt = snapshot.attempts.first;
      final broken = snapshot.copyWith(
        attempts: [
          attempt.copyWith(
            exercise: attempt.exercise.copyWith(number: maxExerciseNumber + 1),
          ),
        ],
      );
      expect(
        problemsOf(broken),
        contains((ImportProblemCode.valueOutOfRange, ImportCategory.attempts)),
      );
    });
  });

  test(
    'an exercise number beyond the rules is refused in every collection',
    () {
      final ack = snapshot.alertAcknowledgements!.first;
      final archive = snapshot.seasonArchives.first;
      final line = archive.exercises.first;
      final broken = snapshot.copyWith(
        alertAcknowledgements: [
          ack.copyWith(
            exercise: ExerciseRef(
              blockId: ack.exercise.blockId,
              number: maxExerciseNumber + 1,
            ),
          ),
        ],
        seasonArchives: [
          archive.copyWith(
            exercises: [
              line.copyWith(
                exercise: ExerciseRef(
                  blockId: line.exercise.blockId,
                  number: maxExerciseNumber + 1,
                ),
              ),
            ],
          ),
        ],
      );
      expect(
        problemsOf(broken),
        containsAll([
          (ImportProblemCode.valueOutOfRange, ImportCategory.acknowledgements),
          (ImportProblemCode.valueOutOfRange, ImportCategory.seasonArchives),
        ]),
      );
    },
  );

  test('the report never carries a first name', () {
    final broken = snapshot.copyWith(
      attempts: [
        for (final ExerciseAttempt a in snapshot.attempts.take(3))
          a.copyWith(sessionId: const SessionId('ghost')),
      ],
    );
    final text = const ImportIntegrity()
        .check(broken)
        .build()
        .map((p) => '$p ${p.sample}')
        .join();
    for (final student in snapshot.students) {
      expect(text, isNot(contains(student.firstName)));
    }
  });
}
