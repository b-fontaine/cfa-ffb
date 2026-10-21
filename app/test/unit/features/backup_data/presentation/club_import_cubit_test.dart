import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/list_import_targets.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/import_world.dart';
import '../../../../support/realistic_backup.dart';

class _OfflineStore implements ClubImportStore {
  static const _down = ServiceFailure(ServiceFailureCode.unavailable);

  @override
  Future<ClubInventory> inventory(String fileId) => Future.error(_down);

  @override
  Future<ImportMarker?> readMarker(String fileId) => Future.error(_down);

  @override
  Future<void> commit(ImportLotCommit commit) => Future.error(_down);
}

class _FailingGroups extends Mock implements GroupRepository;

/// Un club dont la `n`-ième lecture d'inventaire (et les suivantes) échoue ou
/// montre le marqueur d'un autre plan : un autre appareil a écrit entre deux
/// lectures.
class _ScriptedStore implements ClubImportStore {
  _ScriptedStore(this.inner);

  final ClubImportStore inner;
  int calls = 0;
  int? failFrom;
  ServiceFailure? failure;
  int? foreignFrom;

  @override
  Future<ClubInventory> inventory(String fileId) async {
    calls++;
    if (failFrom != null && calls >= failFrom!) throw failure!;
    if (foreignFrom != null && calls >= foreignFrom!) {
      return ClubInventory(
        marker: ImportMarker(
          fileId: fileId,
          planId: 'f' * 64,
          lots: 5,
          done: 1,
          writes: 1,
          restored: 0,
          role: Role.director,
        ),
      );
    }
    return await inner.inventory(fileId);
  }

  @override
  Future<ImportMarker?> readMarker(String fileId) => inner.readMarker(fileId);

  @override
  Future<void> commit(ImportLotCommit commit) => inner.commit(commit);
}

void main() {
  late ImportWorld world;
  late InMemoryBackupFiles files;
  late InMemoryConnectivityStatus network;

  ClubImportCubit open(
    Role role, {
    ClubImportStore? store,
    ClubImportRunner? runner,
    GroupRepository? groups,
  }) {
    world.act(role, groups: world.teacherGroups.toList());
    files = InMemoryBackupFiles();
    network = InMemoryConnectivityStatus();
    final cubit = ClubImportCubit(
      files,
      store == null ? world.prepareUseCase : world.prepareUseCaseWith(store),
      runner ?? world.runner,
      ListImportTargets(
        groups ?? FirestoreGroupRepository(world.club),
        FirestoreSeasonRepository(world.club),
        world.scope,
      ),
      world.scope,
      network,
    )..limits = world.limits;
    addTearDown(cubit.close);
    return cubit;
  }

  setUp(() {
    world = ImportWorld.open();
    final backup = RealisticBackup();
    world
      ..backup = backup
      ..content = backup.content;
  });

  Future<void> pick(ClubImportCubit cubit) async {
    files.nextPick = world.content;
    await cubit.pickFile();
  }

  Future<void> createAll(ClubImportCubit cubit) async {
    for (final group in world.backup!.snapshot.groups) {
      await cubit.chooseGroup(group.id, const CreateGroup());
    }
  }

  test(
    'started reads the role and offers the groups the role may use',
    () async {
      world
        ..seedClubGroup(
          id: 'g-mine',
          name: 'Mine',
          audience: 'children',
          teacher: 'u-import',
        )
        ..seedClubGroup(
          id: 'g-other',
          name: 'Other',
          audience: 'children',
          teacher: 'u-else',
        )
        ..seed('clubs/c1/seasons/season-shut', {
          'label': 'old',
          'startDate': '2025-09-01T00:00:00.000',
          'endDate': '2026-06-30T00:00:00.000',
          'closedOn': '2026-07-01T00:00:00.000',
        })
        ..seed('clubs/c1/groups/g-shut', {
          'seasonId': 'season-shut',
          'name': 'Shut',
          'audience': 'children',
          'teacherUids': ['u-import'],
        })
        ..teacherGroups.addAll(['g-mine', 'g-shut']);
      final teacher = open(Role.teacher);
      await teacher.started();
      expect(teacher.state.role, Role.teacher);
      expect(teacher.state.canCreateGroups, isFalse);
      expect([for (final t in teacher.state.targets) t.name], ['Mine']);

      final director = open(Role.director);
      await director.started();
      expect(director.state.canCreateGroups, isTrue);
      final admin = open(Role.admin);
      await admin.started();
      expect(admin.state.canCreateGroups, isTrue);
      expect([for (final t in director.state.targets) t.name]..sort(), [
        'Mine',
        'Other',
      ]);
    },
  );

  test('a cancelled file choice stays on the file step', () async {
    final cubit = open(Role.director);
    await cubit.started();
    files.nextPick = null;
    await cubit.pickFile();
    expect(cubit.state.step, ClubImportStep.file);
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.plan, isNull);
  });

  test('the whole path: report, groups, recap, run, finish', () async {
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    expect(cubit.state.step, ClubImportStep.report);
    expect(cubit.state.plan!.status, ImportStatus.needsDecisions);
    expect(cubit.state.canContinue, isTrue);

    cubit.next();
    expect(cubit.state.step, ClubImportStep.groups);
    expect(cubit.state.canContinue, isFalse);
    cubit.next(); // refusé : des choix manquent
    expect(cubit.state.step, ClubImportStep.groups);

    await createAll(cubit);
    expect(cubit.state.canContinue, isTrue);
    cubit.next();
    expect(cubit.state.step, ClubImportStep.recap);
    expect(
      world.store.appliedBatches,
      0,
      reason: 'rien écrit avant « Importer »',
    );

    await cubit.start();
    expect(cubit.state.step, ClubImportStep.finished);
    expect(cubit.state.run, isNull);
    expect(cubit.state.doneLots, cubit.state.totalLots);
    expect(world.marker()!['done'], world.marker()!['lots']);
  });

  test('back goes to the previous step to decide, then to the file', () async {
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    cubit.next();
    await createAll(cubit);
    cubit.next();
    expect(cubit.state.step, ClubImportStep.recap);
    cubit.back();
    expect(cubit.state.step, ClubImportStep.groups);
    cubit.back();
    expect(cubit.state.step, ClubImportStep.report);
    cubit.back();
    expect(cubit.state.step, ClubImportStep.file);
    expect(cubit.state.plan, isNull);
    expect(cubit.state.decisions.groups, isEmpty);
    expect(cubit.state.role, Role.director);
  });

  test('a file that cannot be read blocks the way on', () async {
    world.content = 'not json';
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    expect(cubit.state.plan!.status, ImportStatus.blocked);
    expect(cubit.state.canContinue, isFalse);
    cubit.next();
    expect(cubit.state.step, ClubImportStep.report);
    expect(world.store.appliedBatches, 0);
  });

  test(
    'an unreachable club is a failure on the file step, not a crash',
    () async {
      final cubit = open(Role.director, store: _OfflineStore());
      await cubit.started();
      await pick(cubit);
      expect(cubit.state.step, ClubImportStep.file);
      expect(
        (cubit.state.failure! as ServiceFailure).code,
        ServiceFailureCode.unavailable,
      );
      expect(cubit.state.busy, isFalse);
    },
  );

  test(
    'a teacher confirms the records they cannot check by their number',
    () async {
      world.seedClubGroup(
        id: 'g-jeudi',
        name: 'Jeudi',
        audience: 'children',
        teacher: 'u-import',
      );
      world.teacherGroups.add('g-jeudi');
      final single = RealisticBackup(groups: 1);
      world
        ..backup = single
        ..content = single.content;
      final cubit = open(Role.teacher);
      await cubit.started();
      await pick(cubit);
      cubit.next();
      await cubit.chooseGroup(
        single.groupId(1),
        const UseExistingGroup(GroupId('g-jeudi')),
      );
      cubit.next();
      expect(cubit.state.step, ClubImportStep.confirmations);
      expect(cubit.state.plan!.report.unverifiableStudents, 3);
      expect(cubit.state.canContinue, isFalse);
      await cubit.confirmUnverified(confirmed: true);
      expect(cubit.state.decisions.unverifiedConfirmed, 3);
      expect(cubit.state.canContinue, isTrue);
      await cubit.confirmUnverified(confirmed: false);
      expect(cubit.state.canContinue, isFalse);
      await cubit.confirmUnverified(confirmed: true);
      cubit.next();
      expect(cubit.state.step, ClubImportStep.recap);
      await cubit.start();
      expect(cubit.state.step, ClubImportStep.finished);
    },
  );

  test('a plan that is not runnable cannot be started', () async {
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    await cubit.start();
    expect(cubit.state.step, ClubImportStep.report);
    expect(world.store.appliedBatches, 0);
  });

  test(
    'stopping is taken between two batches and resumes at the next one',
    () async {
      world.limits = const ImportLimits(lotSize: 60);
      final cubit = open(Role.director);
      await cubit.started();
      await pick(cubit);
      cubit.next();
      await createAll(cubit);
      cubit.next();
      // Le serveur est lent : l'arrêt est demandé pendant le premier lot.
      world.store.beforeCommit = () async => cubit.cancel();
      await cubit.start();
      world.store.beforeCommit = null;
      expect(cubit.state.run, ClubImportRun.cancelled);
      expect(cubit.state.doneLots, 1);
      expect(world.marker()!['done'], 1);
      await cubit.resume();
      expect(cubit.state.step, ClubImportStep.finished);
      expect(world.marker()!['done'], world.marker()!['lots']);
    },
  );

  test(
    'a cut network interrupts, and the return of the network resumes',
    () async {
      world.limits = const ImportLimits(lotSize: 60);
      world.store.failAfterBatches = 1;
      final cubit = open(Role.director);
      await cubit.started();
      await pick(cubit);
      cubit.next();
      await createAll(cubit);
      cubit.next();
      await cubit.start();
      expect(cubit.state.run, ClubImportRun.interrupted);
      expect(cubit.state.doneLots, 1);
      world.store.failAfterBatches = null;
      network
        ..setOnline(value: false)
        ..setOnline(value: true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.step, ClubImportStep.finished);
    },
  );

  test('the daily limit pauses and the next days finish the import', () async {
    world.limits = const ImportLimits(lotSize: 30, dailyWrites: 60);
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    cubit.next();
    await createAll(cubit);
    cubit.next();
    final days = cubit.state.plan!.daysNeeded;
    expect(days, greaterThan(1));
    await cubit.start();
    expect(cubit.state.run, ClubImportRun.paused);
    expect(cubit.state.runFailure, isNull);
    expect(cubit.state.doneLots, greaterThan(0));
    expect(cubit.state.doneLots, lessThan(cubit.state.totalLots));
    for (var day = 1; day < days; day++) {
      expect(cubit.state.run, ClubImportRun.paused, reason: 'jour $day');
      world.clock.advance(const Duration(days: 1));
      await cubit.resume();
    }
    expect(cubit.state.step, ClubImportStep.finished);
    expect(cubit.state.run, isNull);
    expect(cubit.state.doneLots, cubit.state.totalLots);
  });

  test(
    'an import started with other choices asks for the same choices',
    () async {
      world
        ..limits = const ImportLimits(lotSize: 60)
        ..seedClubGroup(
          id: 'g-jeudi',
          name: 'Jeudi',
          audience: 'children',
          teacher: 'u-import',
        );
      // Premier passage : tous les groupes créés, coupure après un lot.
      world.store.failAfterBatches = 1;
      final first = open(Role.director);
      await first.started();
      await pick(first);
      first.next();
      await createAll(first);
      first.next();
      await first.start();
      expect(first.state.run, ClubImportRun.interrupted);
      world.store.failAfterBatches = null;

      // Reprise : autre choix pour le premier groupe.
      final second = open(Role.director);
      await second.started();
      await pick(second);
      expect(second.state.plan!.outline.marker!.done, 1);
      expect(second.state.groupsNeeded, isTrue);
      second.next();
      expect(second.state.step, ClubImportStep.groups);
      final groups = world.backup!.snapshot.groups;
      await second.chooseGroup(
        groups.first.id,
        const UseExistingGroup(GroupId('g-jeudi')),
      );
      await second.chooseGroup(groups.last.id, const CreateGroup());
      expect(second.state.plan!.awaitsSameChoices, isTrue);
      expect(second.state.canContinue, isFalse);
      // Les mêmes choix qu'au départ : le plan se reprend au lot suivant.
      await createAll(second);
      expect(second.state.plan!.status, ImportStatus.resumable);
      second.next();
      expect(second.state.step, ClubImportStep.recap);
      expect(second.state.plan!.startLot, 1);
    },
  );

  test(
    'another file starts cleanly, without the progress of the first',
    () async {
      world.limits = const ImportLimits(lotSize: 60);
      world.store.failAfterBatches = 1;
      final first = open(Role.director);
      await first.started();
      await pick(first);
      first.next();
      await createAll(first);
      first.next();
      await first.start();
      world.store.failAfterBatches = null;

      final other = RealisticBackup(groups: 1);
      world
        ..backup = other
        ..content = other.content;
      final second = open(Role.director);
      await second.started();
      await pick(second);
      expect(second.state.plan!.outline.marker, isNull);
      expect(second.state.doneLots, 0);
    },
  );

  test('started reports a club it cannot read, and keeps no targets', () async {
    final groups = _FailingGroups();
    when(groups.all)
        .thenThrow(const ServiceFailure(ServiceFailureCode.unavailable));
    final cubit = open(Role.director, groups: groups);
    await cubit.started();
    expect(cubit.state.targets, isEmpty);
    expect(
      (cubit.state.failure! as ServiceFailure).code,
      ServiceFailureCode.unavailable,
    );
  });

  test('a choice can be taken back: groups, sessions and students', () async {
    final orphan = world.backup!.snapshot.copyWith(
      plannedSessions: [
        ...world.backup!.snapshot.plannedSessions,
        Session(
          id: 'p-orphan',
          title: 'Sans groupe',
          date: DateTime(2026, 11, 5),
          audience: Audience.children,
        ),
      ],
    );
    world.content = BackupCodec().encode(
      orphan,
      exportedAt: world.backup!.exportedAt,
    );
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    cubit.next();
    final first = world.backup!.snapshot.groups.first.id;
    await createAll(cubit);
    expect(cubit.state.canContinue, isTrue);
    await cubit.chooseGroup(first, null);
    expect(cubit.state.decisions.groups.containsKey(first), isFalse);
    expect(cubit.state.canContinue, isFalse);
    await cubit.chooseGroup(first, const CreateGroup());
    cubit.next();
    expect(cubit.state.step, ClubImportStep.loose);
    expect(cubit.state.canContinue, isFalse);
    await cubit.chooseSession('p-orphan', AttachTo(first));
    expect(cubit.state.canContinue, isTrue);
    await cubit.chooseSession('p-orphan', null);
    expect(cubit.state.decisions.plannedSessions, isEmpty);
    expect(cubit.state.canContinue, isFalse);
    await cubit.chooseSession('p-orphan', const SkipIt());
    expect(cubit.state.canContinue, isTrue);
  });

  test('a student without a group is decided, then undecided', () async {
    final backup = world.backup!;
    final loose = backup.studentId(1, 1);
    final snapshot = backup.snapshot.copyWith(
      groups: [
        for (final g in backup.snapshot.groups)
          g.copyWith(
            memberships: [
              for (final m in g.memberships)
                if (m.studentId != loose) m,
            ],
          ),
      ],
      attempts: [
        for (final a in backup.snapshot.attempts)
          if (a.studentId != loose) a,
      ],
      blockAcquisitions: [
        RealisticBackup(history: true).snapshot.blockAcquisitions.first
            .copyWith(studentId: loose),
      ],
    );
    world.content = BackupCodec().encode(
      snapshot,
      exportedAt: backup.exportedAt,
    );
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    cubit.next();
    await createAll(cubit);
    cubit.next();
    expect(cubit.state.step, ClubImportStep.loose);
    expect(cubit.state.canContinue, isFalse);
    await cubit.chooseStudent(loose, AttachTo(backup.groupId(1)));
    expect(cubit.state.canContinue, isTrue);
    await cubit.chooseStudent(loose, null);
    expect(cubit.state.decisions.students, isEmpty);
    expect(cubit.state.canContinue, isFalse);
    await cubit.chooseStudent(loose, const SkipIt());
    expect(cubit.state.canContinue, isTrue);
  });

  test('a merge of two file groups needs a confirmation, then none', () async {
    world.seedClubGroup(
      id: 'g-jeudi',
      name: 'Jeudi',
      audience: 'children',
      teacher: 'u-import',
    );
    final trio = RealisticBackup(groups: 3);
    world
      ..backup = trio
      ..content = trio.content;
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    cubit.next();
    // g1 et g3 (enfants) visent le même groupe du club ; g2 (adultes) est créé.
    for (final n in [1, 3]) {
      await cubit.chooseGroup(
        trio.groupId(n),
        const UseExistingGroup(GroupId('g-jeudi')),
      );
    }
    await cubit.chooseGroup(trio.groupId(2), const CreateGroup());
    expect(cubit.state.choices.merges.single.target, const GroupId('g-jeudi'));
    expect(cubit.state.canContinue, isFalse);
    List<ImportProblemCode> codes() => [
      for (final p in cubit.state.plan!.report.problems) p.code,
    ];
    expect(codes(), contains(ImportProblemCode.mergeNotConfirmed));
    await cubit.confirmMerge(const GroupId('g-jeudi'), confirmed: true);
    expect(cubit.state.decisions.confirmedMerges, {const GroupId('g-jeudi')});
    expect(codes(), isNot(contains(ImportProblemCode.mergeNotConfirmed)));
    await cubit.confirmMerge(const GroupId('g-jeudi'), confirmed: false);
    expect(cubit.state.decisions.confirmedMerges, isEmpty);
    expect(codes(), contains(ImportProblemCode.mergeNotConfirmed));
    expect(cubit.state.canContinue, isFalse);
  });

  test('a file written meanwhile by another device is finished, '
      'with no write', () async {
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    cubit.next();
    await createAll(cubit);
    cubit.next();
    // Un autre appareil importe le même fichier avec les mêmes choix.
    world
      ..decisions = world.createAll()
      ..act(Role.director);
    await world.prepare();
    await world.runPlan(budget: 1 << 30);
    final written = world.store.appliedBatches;
    await cubit.start();
    expect(cubit.state.step, ClubImportStep.finished);
    expect(cubit.state.run, isNull);
    expect(cubit.state.busy, isFalse);
    expect(world.store.appliedBatches, written);
  });

  test('a plan changed after the summary writes nothing and says so', () async {
    world.limits = const ImportLimits(lotSize: 60);
    world.store.failAfterBatches = 1;
    final first = open(Role.director);
    await first.started();
    await pick(first);
    first.next();
    await createAll(first);
    first.next();
    await first.start();
    world.store.failAfterBatches = null;
    final second = open(Role.director);
    await second.started();
    await pick(second);
    second.next();
    await createAll(second);
    second.next();
    expect(second.state.plan!.status, ImportStatus.resumable);
    // Entre le récapitulatif et « Importer », le marqueur change de plan.
    final path = world.server.documents.keys.firstWhere(
      (p) => p.contains('/imports/'),
    );
    world.server.seed(path, {...world.marker()!, 'planId': 'f' * 64});
    final written = world.store.appliedBatches;
    await second.start();
    expect(second.state.run, ClubImportRun.planChanged);
    expect(second.state.runFailure, isNull);
    expect(world.store.appliedBatches, written);
  });

  test('a plan changed between the check and the write is the same '
      'outcome', () async {
    final racing = _ScriptedStore(world.importStore);
    final runner = ClubImportRunner(racing, world.dailyLedger);
    final cubit = open(Role.director, store: racing, runner: runner);
    await cubit.started();
    await pick(cubit);
    cubit.next();
    await createAll(cubit);
    cubit.next();
    // Le plan frais est prêt (1 lecture), l'écriture voit un autre marqueur.
    final before = racing.calls;
    racing.foreignFrom = before + 2;
    await cubit.start();
    expect(cubit.state.run, ClubImportRun.planChanged);
    expect(cubit.state.runFailure, isNull);
    expect(world.store.appliedBatches, 0);
  });

  test('a club unreachable while checking the plan interrupts; '
      'another error fails', () async {
    for (final (code, expected) in [
      (ServiceFailureCode.unavailable, ClubImportRun.interrupted),
      (ServiceFailureCode.other, ClubImportRun.failed),
    ]) {
      final scripted = _ScriptedStore(world.importStore);
      final cubit = open(Role.director, store: scripted);
      await cubit.started();
      await pick(cubit);
      cubit.next();
      await createAll(cubit);
      cubit.next();
      scripted
        ..failure = ServiceFailure(code)
        ..failFrom = scripted.calls + 1;
      await cubit.start();
      expect(cubit.state.run, expected, reason: '$code');
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.runFailure, isNotNull);
      expect(world.store.appliedBatches, 0);
    }
  });

  test('a club unreachable while writing interrupts; another error '
      'fails', () async {
    for (final (code, expected) in [
      (ServiceFailureCode.unavailable, ClubImportRun.interrupted),
      (ServiceFailureCode.other, ClubImportRun.failed),
    ]) {
      final scripted = _ScriptedStore(world.importStore);
      final runner = ClubImportRunner(scripted, world.dailyLedger);
      final cubit = open(Role.director, store: scripted, runner: runner);
      await cubit.started();
      await pick(cubit);
      cubit.next();
      await createAll(cubit);
      cubit.next();
      scripted
        ..failure = ServiceFailure(code)
        ..failFrom = scripted.calls + 2;
      await cubit.start();
      expect(cubit.state.run, expected, reason: '$code');
      expect(cubit.state.busy, isFalse);
      expect(world.store.appliedBatches, 0);
    }
  });

  test('a resume after the content was reset never leaves the screen busy; '
      'it goes back to the file choice', () async {
    final cubit = open(Role.director);
    await cubit.started();
    await pick(cubit);
    cubit.next();
    await createAll(cubit);
    cubit
      ..next()
      ..restart();
    await cubit.resume();
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.step, ClubImportStep.file);
    expect(cubit.state.run, isNull);
    expect(world.store.appliedBatches, 0);
  });
}
