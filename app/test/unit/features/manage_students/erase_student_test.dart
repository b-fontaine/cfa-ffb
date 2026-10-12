import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

/// Unité de travail qui échoue à la fin : rien ne doit rester effacé.
class _FailingAtTheEnd implements UnitOfWork {
  @override
  Future<T> run<T>(Future<T> Function() body) =>
      InMemoryUnitOfWork().run(() async {
        await body();
        throw StateError('disque plein');
      });
}

void main() {
  late DomainWorld world;

  EraseStudent build([UnitOfWork? unitOfWork]) => EraseStudent(
    world.students,
    world.groups,
    world.sessions,
    world.attempts,
    world.assessments,
    unitOfWork ?? InMemoryUnitOfWork(),
  );

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    await world.session(present: {'s1', 's2'});
    await world.attempts.add(attempt(ref('a', 1), potted: 3));
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, id: 'a2', student: 's2'),
    );
    await world.assessments.add(
      MaturityAssessment(
        id: const AssessmentId('b1'),
        studentId: const StudentId('s1'),
        date: day(5),
        concentration: 3,
        endurance: 3,
        frustration: 3,
      ),
    );
  });

  test('erases the student and everything that names them', () async {
    ok(await build()(const StudentId('s1')));

    expect(await world.students.byId(const StudentId('s1')), isNull);
    expect(await world.attempts.forStudent(const StudentId('s1')), isEmpty);
    expect(await world.assessments.forStudent(const StudentId('s1')), isEmpty);
    final session = (await world.sessions.byId(const SessionId('x1')))!;
    expect(session.present, {const StudentId('s2')});
    final group = (await world.groups.byId(const GroupId('g1')))!;
    expect(group.memberships.map((m) => m.studentId), [const StudentId('s2')]);
  });

  test('keeps the other students', () async {
    ok(await build()(const StudentId('s1')));

    expect(await world.students.byId(const StudentId('s2')), isNotNull);
    expect(
      await world.attempts.forStudent(const StudentId('s2')),
      hasLength(1),
    );
  });

  test('refuses an unknown student without erasing anything', () async {
    final failure = err(await build()(const StudentId('ghost')));

    expect(
      failure,
      isA<NotFound>()
          .having((e) => e.kind, 'kind', 'student')
          .having((e) => e.id, 'id', 'ghost'),
    );
    expect(await world.students.all(), hasLength(2));
    expect(await world.attempts.all(), hasLength(2));
  });

  test('leaves everything in place when a write fails', () async {
    await expectLater(
      build(_FailingAtTheEnd())(const StudentId('s1')),
      throwsStateError,
    );

    expect(await world.students.byId(const StudentId('s1')), isNotNull);
    expect(
      await world.attempts.forStudent(const StudentId('s1')),
      hasLength(1),
    );
    expect(await world.assessments.all(), hasLength(1));
    final group = (await world.groups.byId(const GroupId('g1')))!;
    expect(group.memberships, hasLength(2));
    final session = (await world.sessions.byId(const SessionId('x1')))!;
    expect(session.present, hasLength(2));
  });
}
