import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/features/manage_students/domain/club_student_erasure.dart';
import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/operations_world.dart';

void main() {
  late OperationsWorld world;
  final lea = OperationsWorld.studentId('Léa');

  setUp(() async {
    world = OperationsWorld();
    await world.seeding((w) async {
      w.seedDirector();
      await w.seedSeason();
      await w.seedGroup('Mardi');
      await w.seedStudent('Léa');
      await w.seedRecord('rec-1', 'Mardi', ['Léa']);
      await w.seedAttempts('Léa', 'rec-1', 2);
    });
  });

  ClubStudentErasure as(Role role) {
    world.scope.activate(OperationsWorld.clubId, role);
    return world.erasure;
  }

  test(
    'inspect gives the preview and says the erasure is not started',
    () async {
      final result = await as(Role.director).inspect(lea);

      final status = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail('$failure'),
      };
      expect(status.synchronized, isTrue);
      expect(status.inProgress, isFalse);
      expect(status.preview.attempts, 2);
    },
  );

  test('inspect says an erasure already started is to resume', () async {
    world.store.failAfterBatches = 1;
    await as(Role.director).erase(lea);
    world.store.failAfterBatches = null;

    final result = await world.erasure.inspect(lea);

    expect((result as Ok<ErasureStatus>).value.inProgress, isTrue);
  });

  test('the marker of an interrupted erasure is keyed by club and student, '
      'so two clubs never share a marker id for the same student id', () async {
    world.store.failAfterBatches = 1;
    await as(Role.director).erase(lea);
    world.store.failAfterBatches = null;

    final expected = operationKey(
      OperationKind.erasure,
      lea.value,
      club: OperationsWorld.clubId,
    );
    final other = operationKey(
      OperationKind.erasure,
      lea.value,
      club: const ClubId('c2'),
    );
    expect(other, isNot(expected));
    expect(
      world.markers().keys.single,
      'clubs/c1/operations/${expected}_u-dir',
    );
  });

  for (final role in [Role.teacher, Role.guardian, Role.student]) {
    test(
      '${role.name} cannot inspect nor erase, and nothing is written',
      () async {
        final erasure = as(role);

        final inspected = await erasure.inspect(lea);
        final erased = await erasure.erase(lea);

        for (final result in [inspected, erased]) {
          expect(result, isA<Err<Object?>>());
          expect(
            ((result as Err<Object?>).failure as ServiceFailure).code,
            ServiceFailureCode.denied,
          );
        }
        expect(world.store.appliedBatches, 0);
      },
    );
  }

  for (final role in Role.values) {
    test('${role.name}: erasing follows the capability of the role policy, not '
        'a list of roles', () async {
      final allowed = role.can(Capability.eraseStudent);

      final inspected = await as(role).inspect(lea);

      expect(inspected is Ok<ErasureStatus>, allowed);
    });
  }

  test('an administrator erases (the matrix of the ADR 0024)', () async {
    final result = await as(Role.admin).erase(lea);

    expect(
      (result as Ok<ErasureOutcome>).value.status,
      OperationRunStatus.completed,
    );
    expect(world.doc('clubs/c1/students/${lea.value}'), isNull);
  });

  test('an unknown student is not found, with nothing written', () async {
    final result = await as(Role.director)
        .erase(OperationsWorld.studentId('Zoé'));

    expect((result as Err<Object?>).failure, isA<NotFound>());
    expect(world.store.appliedBatches, 0);
  });

  test('the progress reports the steps done on the steps planned', () async {
    final progress = <(int, int)>[];

    await as(Role.director)
        .erase(lea, onProgress: (done, total) => progress.add((done, total)));

    expect(progress.first.$1, 0);
    expect(progress.last.$1, progress.last.$2);
  });

  test('stopping is taken between two lots and the rest is resumed', () async {
    var lots = 0;
    final first = await as(Role.director)
        .erase(lea, shouldStop: () => lots++ >= 1);
    expect(
      (first as Ok<ErasureOutcome>).value.status,
      OperationRunStatus.cancelled,
    );
    expect(world.doc('clubs/c1/students/${lea.value}')!['erasing'], isTrue);

    final second = await world.erasure.erase(lea);

    expect(
      (second as Ok<ErasureOutcome>).value.status,
      OperationRunStatus.completed,
    );
    expect(world.doc('clubs/c1/students/${lea.value}'), isNull);
  });

  group('la progression locale des séances guidées (ADR 0020 § 7)', () {
    RunProgress progress(
      String sheet, {
      String? group,
      String? record,
      String? planned,
    }) => RunProgress(
      key: RunProgressKey(
        sheetId: SheetId(sheet),
        groupId: group == null ? null : GroupId(group),
        sessionId: planned,
      ),
      updatedAt: DateTime.utc(2026, 10, 12),
      step: 1,
      recordId: record == null ? null : SessionId(record),
    );

    Future<Set<String>> kept() async => {
      for (final p in await world.runProgress.all()) p.key.sheetId.value,
    };

    test('is erased by the links of the student, others are kept (same list as '
        'EraseStudent)', () async {
      await world.seeding((w) async {
        await w.seedGroup('Jeudi');
        await w.seedPlanned('plan-1', 'Mardi', DateTime(2026, 10, 20));
      });
      await world.runProgress.save(progress('par-groupe', group: 'g-mardi'));
      await world.runProgress.save(progress('par-saisie', record: 'rec-1'));
      await world.runProgress.save(progress('par-seance', planned: 'plan-1'));
      await world.runProgress.save(progress('autre', group: 'g-jeudi'));

      final result = await as(Role.director).erase(lea);

      expect(result, isA<Ok<ErasureOutcome>>());
      expect(await kept(), {'autre'});
    });
  });
}
