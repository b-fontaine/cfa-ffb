import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_world.dart';
import '../../support/fixtures.dart';

/// Parité d'effacement : `CloseSeason` (feature `close_season`) n'a aucune
/// liste de dépôts nominatifs : elle efface par le port `StudentEraser`, que
/// la couche `app` relie à l'enchaînement d'`EraseStudent`. Ce test garantit
/// que ce câblage tient : à données égales, effacer un élève par la clôture ou
/// à la main laisse exactement le même état dans chaque dépôt (un port relié à
/// autre chose, ou une étape oubliée, le fait échouer). Un dépôt ajouté à
/// `EraseStudent` est effacé aux deux endroits sans rien toucher d'autre.
Future<DomainWorld> _seed() async {
  final world = DomainWorld();
  await world.seedClub(studentNames: ['a', 'b']);
  await world.session(dayOfMonth: 3, present: {'a', 'b'});
  for (final student in ['a', 'b']) {
    await world.attempts.add(
      attempt(ref('a', 1), potted: 2, student: student, id: 'p-$student'),
    );
    await world.assessments.add(
      MaturityAssessment(
        id: AssessmentId('m-$student'),
        studentId: StudentId(student),
        date: day(2),
        concentration: 3,
        endurance: 3,
        frustration: 3,
      ),
    );
    await world.acquisitions.add(
      acquisition('b', student: student, id: 'q-$student'),
    );
    await world.acknowledgements.add(
      acknowledgement(
        ref('a', 1),
        lastAttempt: 'p-$student',
        student: student,
        id: 'k-$student',
      ),
    );
  }
  // Séances guidées en cours : une liée au groupe des deux élèves, une à leur
  // séance planifiée, une à la saisie, une sans aucun lien (relecture seule).
  await world.plannedSessions.add(
    Session(
      id: 'p1',
      title: 'Cours',
      date: day(8),
      audience: Audience.children,
      groupId: const GroupId('g1'),
    ),
  );
  for (final (sheet, group, record, planned) in [
    ('posture-1', 'g1', null, null),
    ('posture-2', null, 'x1', null),
    ('posture-3', null, null, null),
    ('posture-4', null, null, 'p1'),
  ]) {
    await world.runProgress.save(
      RunProgress(
        key: RunProgressKey(
          sheetId: SheetId(sheet),
          sessionId: planned,
          groupId: group == null ? null : GroupId(group),
        ),
        updatedAt: DateTime.utc(2026, 10, 12),
        step: 2,
        recordId: record == null ? null : SessionId(record),
        tags: {SessionTag.tooLong},
      ),
    );
  }
  return world;
}

/// Tout ce que les dépôts nominatifs contiennent, sous forme comparable.
Future<Map<String, Object?>> _state(DomainWorld world) async => {
  'students': await world.students.all(),
  'groups': await world.groups.all(),
  'sessions': await world.sessions.all(),
  'attempts': await world.attempts.all(),
  'assessments': await world.assessments.all(),
  'acquisitions': await world.acquisitions.all(),
  'acknowledgements': await world.acknowledgements.all(),
  'runProgress': await world.runProgress.all(),
};

void main() {
  test('erasing a student by closing the season or by hand leaves the same '
      'state in every repository', () async {
    final byHand = await _seed();
    final byClosing = await _seed();

    final erase = EraseStudent(
      byHand.students,
      byHand.groups,
      byHand.sessions,
      byHand.attempts,
      byHand.assessments,
      byHand.acquisitions,
      byHand.acknowledgements,
      byHand.runProgress,
      byHand.plannedSessions,
      InMemoryUnitOfWork(),
    );
    ok(await erase(const StudentId('a')));

    final close = CloseSeason(
      byClosing.seasons,
      byClosing.groups,
      byClosing.students,
      byClosing.sessions,
      byClosing.attempts,
      byClosing.plannedSessions,
      byClosing.seasonArchives,
      byClosing.studentEraser(),
      byClosing.ids,
      InMemoryUnitOfWork(),
    );
    ok(
      await close(
        seasonId: const SeasonId('season'),
        closedOn: day(12),
        erase: {const StudentId('a')},
        prepareNext: false,
        dropPlanned: false,
      ),
    );

    expect(await _state(byClosing), await _state(byHand));
    // L'état comparé est bien vide de l'élève effacé.
    expect((await _state(byHand))['attempts'], hasLength(1));
    // Seule la séance guidée sans lien avec l'élève reste.
    expect((await _state(byHand))['runProgress'], hasLength(1));
  });
}
