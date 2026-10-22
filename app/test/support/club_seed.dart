import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// La forme d'un club à semer : [groups] groupes d'enfants de
/// [studentsPerGroup] élèves chacun ; chaque élève a [attemptsPerStudent]
/// passages et, s'il est « chargé », un bilan, un bloc acquis et un
/// acquittement ; [plannedAfter] séances planifiées après la clôture et une
/// avant.
final class ClubSpec {
  const ClubSpec({
    this.groups = 2,
    this.studentsPerGroup = 6,
    this.attemptsPerStudent = 5,
    this.plannedAfter = 2,
  });

  final int groups;
  final int studentsPerGroup;
  final int attemptsPerStudent;
  final int plannedAfter;

  List<String> get groupNames => [
    for (var g = 0; g < groups; g++) 'Groupe${g + 1}',
  ];
}

/// Les dépôts dans lesquels semer : ceux d'un monde en mémoire, ou ceux d'un
/// club Firestore ouvert sans règles. Rien d'autre que les interfaces du
/// domaine : le même club est semé de la même façon partout.
final class ClubSeedTarget {
  const ClubSeedTarget({
    required this.seasons,
    required this.groups,
    required this.students,
    required this.records,
    required this.attempts,
    required this.assessments,
    required this.acquisitions,
    required this.acknowledgements,
    required this.planned,
  });

  final SeasonRepository seasons;
  final GroupRepository groups;
  final StudentRepository students;
  final SessionRecordRepository records;
  final AttemptRepository attempts;
  final AssessmentRepository assessments;
  final AcquisitionRepository acquisitions;
  final AcknowledgementRepository acknowledgements;
  final SessionRepository planned;
}

/// Ce qui a été semé : les noms d'élèves par groupe (`E01`…), pour choisir qui
/// effacer.
final class SeededClub {
  const SeededClub(this.byGroup);

  final Map<String, List<String>> byGroup;

  List<String> get all => [for (final names in byGroup.values) ...names];

  /// Les [count] premiers élèves de chaque groupe.
  Set<StudentId> firstOfEach(int count) => {
    for (final names in byGroup.values)
      for (final name in names.take(count)) StudentId(idOf(name)),
  };

  static String idOf(String name) => 's-${name.toLowerCase()}';
}

const _seasonId = SeasonId('season');

/// Sème le club décrit par [spec] dans [target] (saison du 1er septembre 2026
/// au 30 juin 2027, groupes homonymes `Groupe1`…, une séance donnée par
/// groupe le 5 octobre avec tous les élèves présents).
Future<SeededClub> seedClub(ClubSpec spec, ClubSeedTarget target) async {
  await target.seasons.save(
    Season(
      id: _seasonId,
      label: '2026-2027',
      startDate: DateTime(2026, 9),
      endDate: DateTime(2027, 6, 30),
    ),
  );
  final byGroup = <String, List<String>>{};
  var n = 0;
  for (var g = 0; g < spec.groups; g++) {
    final name = spec.groupNames[g];
    var group = Group(
      id: GroupId('g-${name.toLowerCase()}'),
      seasonId: _seasonId,
      name: name,
      audience: Audience.children,
    );
    final names = <String>[];
    for (var i = 0; i < spec.studentsPerGroup; i++) {
      n++;
      final student = 'E${n.toString().padLeft(3, '0')}';
      names.add(student);
      final id = StudentId(SeededClub.idOf(student));
      await target.students.create(
        Student.enroll(
          id: id,
          firstName: student,
          audience: Audience.children,
          since: DateTime(2026, 9),
        ),
      );
      group = group.admit(
        studentId: id,
        studentAudience: Audience.children,
        from: DateTime(2026, 9),
      );
    }
    await target.groups.save(group);
    byGroup[name] = names;
    final record = SessionRecord(
      id: SessionId('rec-${name.toLowerCase()}'),
      groupId: group.id,
      seasonId: _seasonId,
      date: DateTime(2026, 10, 5),
      audience: Audience.children,
      present: {
        for (final s in names.take(maxPresentStudents))
          StudentId(SeededClub.idOf(s)),
      },
    );
    await target.records.save(record);
    for (final student in names) {
      final id = StudentId(SeededClub.idOf(student));
      for (var i = 0; i < spec.attemptsPerStudent; i++) {
        await target.attempts.add(
          ExerciseAttempt(
            id: AttemptId('a-${student.toLowerCase()}-$i'),
            studentId: id,
            sessionId: record.id,
            exercise: ExerciseRef(blockId: 'puissance', number: 1 + i % 3),
            date: DateTime(2026, 10, 5),
            potted: 3 + i % 2,
            total: 5,
          ),
        );
      }
      await target.assessments.add(
        MaturityAssessment(
          id: AssessmentId('as-${student.toLowerCase()}'),
          studentId: id,
          date: DateTime(2026, 10, 5),
          concentration: 3,
          endurance: 2,
          frustration: 4,
        ),
      );
      await target.acquisitions.add(
        BlockAcquisition(
          id: AcquisitionId('q-${student.toLowerCase()}'),
          studentId: id,
          blockId: 'puissance',
          date: DateTime(2026, 9, 15),
          source: AcquisitionSource.placement,
        ),
      );
      await target.acknowledgements.add(
        AlertAcknowledgement(
          id: AcknowledgementId('k-${student.toLowerCase()}'),
          studentId: id,
          exercise: ExerciseRef(blockId: 'puissance', number: 1),
          lastAttemptId: AttemptId('a-${student.toLowerCase()}-0'),
          date: DateTime(2026, 10, 5),
        ),
      );
    }
    for (var p = 0; p < spec.plannedAfter; p++) {
      await target.planned.add(
        Session(
          id: 'plan-${name.toLowerCase()}-after-$p',
          title: 'Après $p',
          date: DateTime(2026, 10, 20 + p),
          audience: Audience.children,
          groupId: group.id,
        ),
      );
    }
    await target.planned.add(
      Session(
        id: 'plan-${name.toLowerCase()}-before',
        title: 'Avant',
        date: DateTime(2026, 10, 8),
        audience: Audience.children,
        groupId: group.id,
      ),
    );
  }
  return SeededClub(byGroup);
}

/// L'état d'un club vu par les dépôts, sans les identifiants qui dépendent de
/// la réalisation (identifiants de groupes et de saisons créés par la
/// clôture) : de quoi comparer une clôture en un seul lot et une clôture par
/// lots, sur n'importe quel stockage.
Future<Map<String, Object?>> canonicalState({
  required SeasonRepository seasons,
  required GroupRepository groups,
  required StudentRepository students,
  required SessionRecordRepository records,
  required AttemptRepository attempts,
  required AssessmentRepository assessments,
  required AcquisitionRepository acquisitions,
  required AcknowledgementRepository acknowledgements,
  required SessionRepository planned,
  required SeasonArchiveRepository archives,
}) async {
  final allSeasons = await seasons.all();
  final labelOf = {for (final s in allSeasons) s.id: s.label};
  String day(DateTime? d) => d == null ? '-' : d.toIso8601String();
  String row(List<Object?> parts) => parts.join('|');
  List<String> sorted(Iterable<String> rows) => rows.toList()..sort();
  final allGroups = await groups.all();
  return {
    'seasons': sorted([
      for (final s in allSeasons)
        row([s.label, day(s.startDate), day(s.endDate), day(s.closedOn)]),
    ]),
    'groups': sorted([
      for (final g in allGroups)
        row([
          labelOf[g.seasonId],
          g.name,
          g.audience.name,
          sorted([
            for (final m in g.memberships)
              '${m.studentId.value}@${day(m.from)}>${day(m.to)}',
          ]).join(','),
        ]),
    ]),
    'students': sorted([
      for (final s in await students.all())
        row([s.id.value, s.firstName, s.audienceHistory.length]),
    ]),
    'records': sorted([
      for (final r in await records.all())
        row([
          r.id.value,
          day(r.date),
          sorted([for (final p in r.present) p.value]).join(','),
        ]),
    ]),
    'attempts': sorted([
      for (final a in await attempts.all())
        row([a.id.value, a.studentId.value, '${a.potted}/${a.total}']),
    ]),
    'assessments': sorted([
      for (final a in await assessments.all()) a.studentId.value,
    ]),
    'acquisitions': sorted([
      for (final a in await acquisitions.all()) a.studentId.value,
    ]),
    'acknowledgements': sorted([
      for (final a in await acknowledgements.all()) a.studentId.value,
    ]),
    'planned': sorted([for (final s in await planned.getAll()) s.id]),
    'archives': sorted([
      for (final a in await archives.all()) ...[
        for (final b in a.audiences)
          row([
            labelOf[a.seasonId],
            b.audience.name,
            b.sessionCount,
            b.presenceCount,
            b.possiblePresenceCount,
            b.studentCount,
            b.attemptCount,
          ]),
        for (final e in a.exercises)
          row([
            labelOf[a.seasonId],
            e.audience.name,
            e.exercise.blockId,
            e.exercise.number,
            e.studentCount,
            e.attemptCount,
            '${e.potted}/${e.total}',
          ]),
      ],
    ]),
  };
}
