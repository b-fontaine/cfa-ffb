import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/features/manage_students/domain/enroll_student.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';

/// Garde les lots reçus : ce que les règles verront, écriture par écriture.
class _Recording extends InMemoryDocumentStore {
  final List<List<WriteOp>> batches = [];

  @override
  Future<void> commit(List<WriteOp> operations) {
    batches.add(operations);
    return super.commit(operations);
  }
}

/// Un enseignant du groupe `g1` inscrit un élève (FB4, partie 2, point A) : le
/// cas d'usage écrit la fiche AVEC son groupe et l'appartenance dans **un
/// seul lot**, sans toucher à la saison ni au groupe qu'il n'a pas le droit
/// d'écrire. Les règles correspondantes sont jouées contre l'émulateur
/// (`scripts/rules_test/repositories.test.mjs`).
void main() {
  late _Recording documents;
  late EnrollStudent enroll;

  setUp(() {
    documents = _Recording()
      ..seed('clubs/c1/seasons/se1', {
        'label': '2026-2027',
        'startDate': DateTime(2026, 9).toIso8601String(),
        'endDate': DateTime(2027, 8, 31).toIso8601String(),
        'closedOn': null,
        'createdAt': DateTime(2026, 9),
      })
      ..seed('clubs/c1/groups/g1', {
        'seasonId': 'se1',
        'name': 'Mardi',
        'audience': 'children',
        'teacherUids': ['u-teacher'],
      });
    final scope = SessionScope()
      ..signIn(const UserId('u-teacher'))
      ..activate(
        const ClubId('c1'),
        Role.teacher,
        groupIds: const [GroupId('g1')],
      );
    final club = ClubStore(documents, scope);
    enroll = EnrollStudent(
      FirestoreStudentRepository(club),
      FirestoreGroupRepository(club),
      FirestoreSeasonRepository(club),
      SequentialIdGenerator(),
      FirestoreUnitOfWork(club),
    );
  });

  test('writes the sheet, its group and the membership in one batch', () async {
    final enrolled = ok(
      await enroll(
        firstName: 'Léa',
        audience: Audience.children,
        today: DateTime(2026, 10, 12),
        groupId: const GroupId('g1'),
      ),
    );

    expect(documents.batches, hasLength(1));
    final ops = documents.batches.single;
    expect([for (final op in ops) op.path]..sort(), [
      'clubs/c1/memberships/g1_${enrolled.student.id.value}_2026-09-01T00:00:00.000',
      'clubs/c1/students/${enrolled.student.id.value}',
    ], reason: 'ni la saison ni le groupe ne sont réécrits');
    final student = documents.read(
      'clubs/c1/students/${enrolled.student.id.value}',
    );
    expect(student!['groupIds'], ['g1']);
    expect(student['createdAt'], isNotNull);
  });

  test('the sheet is created once, never twice, in the batch', () async {
    await enroll(
      firstName: 'Léa',
      audience: Audience.children,
      today: DateTime(2026, 10, 12),
      groupId: const GroupId('g1'),
    );

    final ops = documents.batches.single;
    final paths = [for (final op in ops) op.path];
    expect(paths.toSet(), hasLength(paths.length));
  });
}
