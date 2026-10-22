import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/operations_world.dart';

void main() {
  late OperationsWorld world;
  final lea = OperationsWorld.studentId('Léa');
  final tom = OperationsWorld.studentId('Tom');

  setUp(() async {
    world = OperationsWorld();
    await world.seeding((w) async {
      w.seedDirector();
      await w.seedSeason();
      await w.seedGroup('Mardi');
      await w.seedStudent('Léa');
      await w.seedStudent('Tom');
      await w.seedRecord('rec-1', 'Mardi', ['Léa', 'Tom']);
      await w.seedAttempts('Léa', 'rec-1', 3);
      await w.seedAttempts('Tom', 'rec-1', 2);
      await w.seedAssessment('Léa');
      await w.seedAcquisition('Léa');
      await w.seedAcknowledgement('Léa');
      w.seedGuardian('Léa');
    });
  });

  Future<void> apply(Iterable<dynamic> lots) async {
    for (final lot in lots) {
      await ClubStore(
        world.store,
        world.scope,
      ).atomically(() async => await (lot as OperationLot).apply());
    }
  }

  test(
    'the preview counts what is linked to the student, nothing else',
    () async {
      final preview = await world.purge.preview(lea);

      expect(preview.attempts, 3);
      expect(preview.assessments, 1);
      expect(preview.acquisitions, 1);
      expect(preview.acknowledgements, 1);
      expect(preview.memberships, 1);
      expect(preview.presences, 1);
      expect(preview.accountLinks, 1);
      expect(preview.total, 9);
    },
  );

  test('the preview of a student with nothing is empty', () async {
    final preview = await world.purge.preview(const StudentId('inconnu'));

    expect(preview.total, 0);
  });

  test('exists follows the record, flagged follows the mark', () async {
    expect(await world.purge.exists(lea), isTrue);
    expect(await world.purge.exists(const StudentId('inconnu')), isFalse);
    expect(await world.purge.flagged(), isEmpty);

    await apply([
      world.purge.flag({lea}),
    ]);

    expect(await world.purge.flagged(), {lea});
    expect(world.doc('clubs/c1/students/${lea.value}')!['erasing'], isTrue);
    expect(world.doc('clubs/c1/students/${tom.value}')!['erasing'], isNull);
  });

  test(
    'the purge removes the account linked to this student alone, first',
    () async {
      final lots = await world.purge.purgeLots({lea}, maxWrites: 399);

      expect(lots, hasLength(1));
      await apply(lots);
      expect(world.doc('clubs/c1/members/u-parent'), isNull);
      // Au lot unique : liens, présences, puis suppressions.
      expect(world.documentsAboutId(lea.value), [
        'clubs/c1/students/${lea.value}',
      ]);
    },
  );

  test(
    'the purge takes the student out of the present lists without reading them',
    () async {
      await apply(await world.purge.purgeLots({lea}, maxWrites: 399));

      expect(world.doc('clubs/c1/records/rec-1')!['presentStudentIds'], [
        tom.value,
      ]);
    },
  );

  test(
    'a presence or a link added by another device between the planning and '
    'the application of a lot survives: lists are never read then rewritten',
    () async {
      // Un parent lié à deux élèves : il garde son compte, sans le lien.
      world.seedGuardian('Léa', also: ['Tom']);
      final lots = await world.purge.purgeLots({lea}, maxWrites: 399);
      // Un autre appareil ajoute un présent et un lien après la planification.
      final record = world.server.documents['clubs/c1/records/rec-1']!;
      world.server.seed('clubs/c1/records/rec-1', {
        ...record,
        'presentStudentIds': [...record['presentStudentIds']! as List, 'zoe'],
      });
      final member = world.server.documents['clubs/c1/members/u-parent']!;
      world.server.seed('clubs/c1/members/u-parent', {
        ...member,
        'studentIds': [...member['studentIds']! as List, 'zoe'],
      });

      await apply(lots);

      expect(world.doc('clubs/c1/records/rec-1')!['presentStudentIds'], [
        tom.value,
        'zoe',
      ]);
      expect(world.doc('clubs/c1/members/u-parent')!['studentIds'], [
        tom.value,
        'zoe',
      ]);
    },
  );

  test('the purge keeps the other student, the tags and the record', () async {
    await apply(await world.purge.purgeLots({lea}, maxWrites: 399));

    final tomAttempts = [
      for (final e in world.server.documents.entries)
        if (e.key.contains('/attempts/') && e.value['studentId'] == tom.value)
          e.key,
    ];
    expect(tomAttempts, hasLength(2));
    expect(world.doc('clubs/c1/students/${tom.value}'), isNotNull);
    expect(world.doc('clubs/c1/records/rec-1'), isNotNull);
  });

  test('the purge is cut into lots of the asked size, links first', () async {
    final lots = await world.purge.purgeLots({lea}, maxWrites: 3);

    expect([for (final lot in lots) lot.writes], [3, 3, 3]);
    // Le premier lot porte le compte lié et la présence.
    await apply(lots.take(1));
    expect(world.doc('clubs/c1/members/u-parent'), isNull);
    expect(world.doc('clubs/c1/records/rec-1')!['presentStudentIds'], [
      tom.value,
    ]);
  });

  test('what is left is recomputed after a partial purge', () async {
    final lots = await world.purge.purgeLots({lea}, maxWrites: 3);
    await apply(lots.take(2));

    final left = await world.purge.purgeLots({lea}, maxWrites: 3);

    expect([for (final lot in left) lot.writes], [3]);
    await apply(left);
    expect(await world.purge.purgeLots({lea}, maxWrites: 3), isEmpty);
  });

  test('several students are packed together in the same lots', () async {
    final lots = await world.purge.purgeLots({lea, tom}, maxWrites: 399);

    expect(lots, hasLength(1));
    expect(lots.single.writes, greaterThan(9));
  });

  test('the record is removed last, on its own, by a lot of its own', () async {
    final lot = world.purge.removeRecords({lea});
    await apply([lot]);

    expect(lot.writes, 1);
    expect(world.doc('clubs/c1/students/${lea.value}'), isNull);
    expect(world.doc('clubs/c1/students/${tom.value}'), isNotNull);
  });

  test('the rules refuse a purge by a role without the right', () async {
    // Le port n'impose aucun rôle : le serveur refuse ce que les règles ne
    // permettent pas (voir scripts/rules_test/operations.test.mjs).
    world.store.denyAll = true;

    await expectLater(
      ClubStore(
        world.store,
        world.scope,
      ).commit([const DeleteOp('clubs/c1/students/s-lea')]),
      throwsA(isA<StoreFailure>()),
    );
  });
}
