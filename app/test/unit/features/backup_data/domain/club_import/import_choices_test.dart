import 'package:billard_cfa/features/backup_data/domain/club_import/import_choices.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_outline.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

ImportTarget target(String id, String name, Audience audience) =>
    ImportTarget(id: GroupId(id), name: name, audience: audience);

OutlineGroup fileGroup(String id, String name, Audience audience) =>
    OutlineGroup(
      id: GroupId(id),
      name: name,
      audience: audience,
      seasonLabel: null,
      students: 1,
    );

ClubImportPlan planOf({
  required List<OutlineGroup> groups,
  List<GroupId> undecidedGroups = const [],
  List<String> undecidedSessions = const [],
  List<StudentId> undecidedStudents = const [],
  List<OutlineSession> sessions = const [],
  List<OutlineStudent> students = const [],
  ImportStatus status = ImportStatus.needsDecisions,
  ImportMarker? marker,
  List<ImportProblem> problems = const [],
}) => ClubImportPlan(
  status: status,
  report: ImportReport(
    counts: const {},
    problems: problems,
    undecidedGroups: undecidedGroups,
    undecidedSessions: undecidedSessions,
    undecidedStudents: undecidedStudents,
  ),
  outline: ImportOutline(
    groups: groups,
    looseSessions: sessions,
    looseStudents: students,
    marker: marker,
  ),
);

void main() {
  final kids = fileGroup('f1', 'Enfants', Audience.children);
  final adults = fileGroup('f2', 'Adultes', Audience.adults);
  final mardi = target('c1', 'Mardi', Audience.children);
  final jeudi = target('c2', 'Jeudi', Audience.adults);

  group('ImportActor', () {
    test('only a manager writes anywhere, a teacher in their groups', () {
      const director = ImportActor(Role.director);
      expect(director.mayWriteTo(const GroupId('x')), isTrue);
      expect(
        const ImportActor(Role.admin).mayWriteTo(const GroupId('x')),
        isTrue,
      );
      const teacher = ImportActor(Role.teacher, {GroupId('mine')});
      expect(teacher.mayWriteTo(const GroupId('mine')), isTrue);
      expect(teacher.mayWriteTo(const GroupId('other')), isFalse);
    });
  });

  group('choices are values', () {
    test('equal when they name the same target', () {
      expect(const CreateGroup(), const CreateGroup());
      expect(
        const UseExistingGroup(GroupId('a')),
        const UseExistingGroup(GroupId('a')),
      );
      expect(
        const UseExistingGroup(GroupId('a')),
        isNot(const UseExistingGroup(GroupId('b'))),
      );
      expect(const AttachTo(GroupId('a')), const AttachTo(GroupId('a')));
      expect(const AttachTo(GroupId('a')), isNot(const SkipIt()));
      expect(const SkipIt(), const SkipIt());
      expect(
        const AttachTo(GroupId('a')).hashCode,
        const AttachTo(GroupId('a')).hashCode,
      );
      expect(
        const UseExistingGroup(GroupId('a')).hashCode,
        const UseExistingGroup(GroupId('a')).hashCode,
      );
    });
  });

  group('ClubImportPlan.awaitsSameChoices', () {
    const marker = ImportMarker(
      fileId: 'f',
      planId: 'p',
      lots: 3,
      done: 1,
      writes: 1,
      restored: 0,
      role: Role.director,
    );
    const changed = ImportProblem(ImportProblemCode.planChanged, null);

    test('a blocked plan whose only problem is the changed choices', () {
      final plan = planOf(
        groups: [kids],
        status: ImportStatus.blocked,
        marker: marker,
        problems: [changed],
      );
      expect(plan.awaitsSameChoices, isTrue);
    });

    test('not without a started import, nor with another problem', () {
      expect(
        planOf(
          groups: [kids],
          status: ImportStatus.blocked,
          problems: [changed],
        ).awaitsSameChoices,
        isFalse,
      );
      expect(
        planOf(
          groups: [kids],
          status: ImportStatus.blocked,
          marker: marker,
          problems: [
            changed,
            const ImportProblem(ImportProblemCode.invalid, null),
          ],
        ).awaitsSameChoices,
        isFalse,
      );
      expect(
        planOf(
          groups: [kids],
          status: ImportStatus.blocked,
          marker: marker,
        ).awaitsSameChoices,
        isFalse,
      );
      expect(
        planOf(
          groups: [kids],
          marker: marker,
          problems: [changed],
        ).awaitsSameChoices,
        isFalse,
      );
    });
  });

  group('ImportChoices', () {
    test('targets of a group are those of the same audience', () {
      final choices = ImportChoices.of(
        plan: planOf(groups: [kids, adults]),
        decisions: ImportDecisions.none,
        targets: [mardi, jeudi],
      );
      expect(choices.targetsFor(kids), [mardi]);
      expect(choices.targetsFor(adults), [jeudi]);
    });

    test('groups to show: undecided, decided, or all once started', () {
      final undecided = planOf(
        groups: [kids, adults],
        undecidedGroups: [kids.id],
      );
      expect(
        ImportChoices.of(
          plan: undecided,
          decisions: ImportDecisions.none,
          targets: const [],
        ).groups,
        [kids],
      );
      expect(
        ImportChoices.of(
          plan: undecided,
          decisions: ImportDecisions(groups: {adults.id: const CreateGroup()}),
          targets: const [],
        ).groups,
        [kids, adults],
      );
      const marker = ImportMarker(
        fileId: 'f',
        planId: 'p',
        lots: 2,
        done: 1,
        writes: 1,
        restored: 0,
        role: Role.director,
      );
      expect(
        ImportChoices.of(
          plan: planOf(groups: [kids, adults], marker: marker),
          decisions: ImportDecisions.none,
          targets: const [],
        ).groups,
        [kids, adults],
      );
    });

    test('merges list the club groups chosen by several file groups', () {
      final choices = ImportChoices.of(
        plan: planOf(groups: [kids, adults]),
        decisions: ImportDecisions(
          groups: {
            kids.id: UseExistingGroup(mardi.id),
            adults.id: UseExistingGroup(mardi.id),
          },
        ),
        targets: [mardi],
      );
      expect(choices.merges.single.target, mardi.id);
      expect(choices.merges.single.name, 'Mardi');
      final alone = ImportChoices.of(
        plan: planOf(groups: [kids, adults]),
        decisions: ImportDecisions(
          groups: {kids.id: UseExistingGroup(mardi.id)},
        ),
        targets: [mardi],
      );
      expect(alone.merges, isEmpty);
    });

    test('destinations follow the decisions', () {
      final plan = planOf(
        groups: [
          kids,
          adults,
          fileGroup('f3', 'Libre', Audience.children),
          fileGroup('f4', 'Déjà là', Audience.children),
        ],
        undecidedGroups: [kids.id, adults.id, const GroupId('f3')],
      );
      final choices = ImportChoices.of(
        plan: plan,
        decisions: ImportDecisions(
          groups: {
            kids.id: const CreateGroup(),
            adults.id: UseExistingGroup(jeudi.id),
          },
        ),
        targets: [mardi, jeudi],
      );
      expect(
        [for (final d in choices.destinations) (d.id.value, d.name)],
        [('f1', 'Enfants'), ('c2', 'Jeudi'), ('f4', 'Déjà là')],
      );
    });

    test('a target missing from the list keeps the name of the file group', () {
      final choices = ImportChoices.of(
        plan: planOf(groups: [kids], undecidedGroups: [kids.id]),
        decisions: ImportDecisions(
          groups: {kids.id: const UseExistingGroup(GroupId('gone'))},
        ),
        targets: const [],
      );
      expect(choices.destinations.single.name, 'Enfants');
      expect(choices.destinations.single.id.value, 'gone');
    });

    test('loose sessions and students: undecided or already decided', () {
      final s1 = OutlineSession(id: 's1', title: 'A', date: DateTime(2026));
      final s2 = OutlineSession(id: 's2', title: 'B', date: DateTime(2026));
      final s3 = OutlineSession(id: 's3', title: 'C', date: DateTime(2026));
      const t1 = OutlineStudent(id: StudentId('t1'), firstName: 'X');
      const t2 = OutlineStudent(id: StudentId('t2'), firstName: 'Y');
      const t3 = OutlineStudent(id: StudentId('t3'), firstName: 'Z');
      final choices = ImportChoices.of(
        plan: planOf(
          groups: [kids],
          undecidedSessions: ['s1'],
          undecidedStudents: [t1.id],
          sessions: [s1, s2, s3],
          students: [t1, t2, t3],
        ),
        decisions: const ImportDecisions(
          plannedSessions: {'s2': SkipIt()},
          students: {StudentId('t2'): SkipIt()},
        ),
        targets: const [],
      );
      expect(choices.sessions, [s1, s2]);
      expect(choices.students, [t1, t2]);
    });

    test('nothing without a plan', () {
      const none = ImportChoices.empty;
      expect(none.groups, isEmpty);
      expect(none.destinations, isEmpty);
      expect(none.merges, isEmpty);
      expect(none.sessions, isEmpty);
      expect(none.students, isEmpty);
      expect(none.targetsFor(kids), isEmpty);
    });
  });
}
