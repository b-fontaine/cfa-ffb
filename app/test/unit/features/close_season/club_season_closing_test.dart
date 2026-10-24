import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/operations_world.dart';

void main() {
  late OperationsWorld world;

  setUp(() async {
    world = OperationsWorld();
    await world.seeding((w) async {
      w.seedDirector();
      await w.seedSeason();
    });
  });

  for (final role in Role.values) {
    test('${role.name}: closing follows the capability of the role policy, not '
        'a list of roles', () async {
      world.scope.activate(OperationsWorld.clubId, role);

      final result = await world.closing.pending();

      if (role.can(Capability.closeSeason)) {
        expect(result, isA<Ok<Object?>>());
      } else {
        expect(
          ((result as Err<Object?>).failure as ServiceFailure).code,
          ServiceFailureCode.denied,
        );
      }
    });
  }

  for (final role in Role.values) {
    test('${role.name}: counting the invitations to delete follows the '
        'capability to close', () async {
      world.scope.activate(OperationsWorld.clubId, role);
      world.store.admin = role == Role.admin;

      final result = await world.closing.invitationsToPurge();

      if (role.can(Capability.closeSeason)) {
        expect(result, isA<Ok<int>>(), reason: '$result');
      } else {
        expect(
          ((result as Err<int>).failure as ServiceFailure).code,
          ServiceFailureCode.denied,
        );
        expect(world.store.invitationQueries, isEmpty);
      }
    });
  }

  test('invitations that cannot be listed are a failure of the preview, '
      'never zero', () async {
    world.scope.activate(OperationsWorld.clubId, Role.director);
    world.store.denyAll = true;

    final result = await world.closing.invitationsToPurge();

    expect(
      ((result as Err<int>).failure as ServiceFailure).code,
      ServiceFailureCode.denied,
    );
  });

  test('closing with an erased student also erases the local guided-run '
      'progress linked to it, by the same links as EraseStudent', () async {
    await world.seeding((w) async {
      await w.seedGroup('Mardi');
      await w.seedGroup('Jeudi');
      await w.seedStudent('Léa');
      await w.seedRecord('rec-1', 'Mardi', ['Léa']);
    });
    RunProgress progress(String sheet, {String? group}) => RunProgress(
      key: RunProgressKey(
        sheetId: SheetId(sheet),
        groupId: group == null ? null : GroupId(group),
      ),
      updatedAt: DateTime.utc(2026, 10, 12),
      step: 1,
    );
    await world.runProgress.save(progress('mardi', group: 'g-mardi'));
    await world.runProgress.save(progress('jeudi', group: 'g-jeudi'));
    world.scope.activate(OperationsWorld.clubId, Role.director);

    final result = await world.closing.close(
      seasonId: OperationsWorld.seasonId,
      closedOn: OperationsWorld.day,
      erase: {OperationsWorld.studentId('Léa')},
    );

    expect(result, isA<Ok<ClosureOutcome>>());
    expect(
      {for (final p in await world.runProgress.all()) p.key.sheetId.value},
      {'jeudi'},
    );
  });

  test('CHARACTERISATION (known limit, ADR 0025): a closure started by '
      'ANOTHER manager is not detected, only the marker of the current '
      'account is read; the second closure converges instead of being '
      'refused', () async {
    await world.seeding((w) async {
      await w.seedGroup('Mardi');
      await w.seedStudent('Léa');
    });
    world.scope.activate(OperationsWorld.clubId, Role.director);
    world.store.failAfterBatches = 1;
    await world.closing.close(
      seasonId: OperationsWorld.seasonId,
      closedOn: OperationsWorld.day,
      erase: {OperationsWorld.studentId('Léa')},
    );
    world.store.failAfterBatches = null;
    final other = world.actor(uid: 'u-admin', role: Role.admin);

    final pending = await other.closing.pending();
    final second = await other.closing.close(
      seasonId: OperationsWorld.seasonId,
      closedOn: OperationsWorld.day,
      erase: const {},
    );

    expect((pending as Ok<ClosureTerms?>).value, isNull);
    expect(second, isA<Ok<ClosureOutcome>>());
  });
}
