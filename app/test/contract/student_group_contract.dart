import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

Student _student(String id, String name, {DateTime? since}) => Student.enroll(
  id: StudentId(id),
  firstName: name,
  audience: Audience.children,
  since: since ?? DateTime(2026, 9),
);

Group _group(String id, {String name = 'Jeunes', Audience? audience}) => Group(
  id: GroupId(id),
  seasonId: const SeasonId('season'),
  name: name,
  audience: audience ?? Audience.children,
);

/// Les deux ports d'un stockage neuf et sa fermeture.
typedef StudentGroupRepos = ({
  StudentRepository students,
  GroupRepository groups,
  Future<void> Function() close,
});

/// Suite du contrat des élèves et des groupes, exécutée contre chaque
/// implémentation : drift, mémoire, et Firestore (sur `fake_cloud_firestore`
/// côté Dart, voir `docs/engineering/testing.md` pour ce que cela ne prouve
/// pas). Elle ne suppose aucun lien entre les deux dépôts.
void studentGroupContract(
  String label,
  Future<StudentGroupRepos> Function() open,
) {
  group('$label : contrat des élèves et des groupes', () {
    late StudentGroupRepos repos;

    setUp(() async => repos = await open());
    tearDown(() => repos.close());

    group('élèves', () {
      test('returns null for an unknown student', () async {
        expect(await repos.students.byId(const StudentId('x')), isNull);
      });

      test('round-trips the audience history and the exact dates', () async {
        final student = Student.enroll(
          id: const StudentId('s1'),
          firstName: 'Zoë-Léa',
          audience: Audience.children,
          since: DateTime(2026, 9, 1, 14, 30, 15, 123, 456),
        ).changeAudience(Audience.adults, DateTime.utc(2028, 9));

        await repos.students.save(student);

        final loaded = await repos.students.byId(const StudentId('s1'));
        expect(loaded, student);
        expect(loaded!.audienceHistory.last.effectiveFrom.isUtc, isTrue);
        expect(loaded.audienceHistory.first.effectiveFrom.isUtc, isFalse);
      });

      test('keeps the order of first save and replaces by id', () async {
        await repos.students.save(_student('s1', 'Léa'));
        await repos.students.save(_student('s2', 'Théo'));
        await repos.students.save(_student('s1', 'Léa-Rose'));

        final all = await repos.students.all();
        expect(all.map((s) => s.firstName), ['Léa-Rose', 'Théo']);
      });

      test('hides a deleted student and ignores unknown deletions', () async {
        await repos.students.save(_student('s1', 'Léa'));
        await repos.students.save(_student('s2', 'Théo'));

        await repos.students.delete(const StudentId('s1'));
        await repos.students.delete(const StudentId('unknown'));

        expect(await repos.students.byId(const StudentId('s1')), isNull);
        expect((await repos.students.all()).map((s) => s.id.value), ['s2']);
      });

      test('restores a deleted student when it is saved again', () async {
        await repos.students.save(_student('s1', 'Léa'));
        await repos.students.delete(const StudentId('s1'));

        await repos.students.save(_student('s1', 'Léa'));

        expect(await repos.students.byId(const StudentId('s1')), isNotNull);
        expect(await repos.students.all(), hasLength(1));
      });
    });

    group('groupes', () {
      test('round-trips open and closed memberships', () async {
        final group = _group('g1')
            .admit(
              studentId: const StudentId('s1'),
              studentAudience: Audience.children,
              from: DateTime(2026, 9),
            )
            .release(studentId: const StudentId('s1'), to: DateTime(2027))
            .admit(
              studentId: const StudentId('s1'),
              studentAudience: Audience.children,
              from: DateTime(2027),
            )
            .admit(
              studentId: const StudentId('s2'),
              studentAudience: Audience.children,
              from: DateTime(2026, 10),
            );

        await repos.groups.save(group);

        expect(await repos.groups.byId(const GroupId('g1')), group);
      });

      test('round-trips an adults group', () async {
        final group = _group('g', audience: Audience.adults);

        await repos.groups.save(group);

        expect(await repos.groups.byId(const GroupId('g')), group);
      });

      test('returns null for an unknown group', () async {
        expect(await repos.groups.byId(const GroupId('x')), isNull);
      });

      test('finds the groups a student was ever a member of, closed periods '
          'included', () async {
        await repos.groups.save(
          _group('g1').admit(
            studentId: const StudentId('s1'),
            studentAudience: Audience.children,
            from: DateTime(2026, 9),
          ),
        );
        await repos.groups.save(
          _group('g2')
              .admit(
                studentId: const StudentId('s1'),
                studentAudience: Audience.children,
                from: DateTime(2026, 9),
              )
              .release(
                studentId: const StudentId('s1'),
                to: DateTime(2026, 10),
              ),
        );
        await repos.groups.save(
          _group('g3').admit(
            studentId: const StudentId('s2'),
            studentAudience: Audience.children,
            from: DateTime(2026, 9),
          ),
        );
        await repos.groups.save(_group('g4'));

        expect(await repos.groups.idsEverContaining(const StudentId('s1')), {
          const GroupId('g1'),
          const GroupId('g2'),
        });
        expect(
          await repos.groups.idsEverContaining(const StudentId('inconnu')),
          isEmpty,
        );
      });

      test('replaces, lists in order and deletes logically', () async {
        await repos.groups.save(_group('g1'));
        await repos.groups.save(_group('g2', name: 'Adultes'));
        await repos.groups.save(_group('g1', name: 'Jeunes 2'));
        await repos.groups.delete(const GroupId('g2'));

        final all = await repos.groups.all();
        expect(all.map((g) => g.name), ['Jeunes 2']);
        expect(await repos.groups.byId(const GroupId('g2')), isNull);
      });
    });
  });
}
