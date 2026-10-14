import 'package:billard_cfa/entities/exercise_result/data/in_memory_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/features/place_student/domain/mark_block_acquired.dart';
import 'package:billard_cfa/features/place_student/domain/revoke_block_acquired.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

const _student = StudentId('s1');

void main() {
  late DomainWorld world;
  late MarkBlockAcquired mark;
  late RevokeBlockAcquired revoke;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    mark = MarkBlockAcquired(
      world.students,
      world.acquisitions,
      world.catalogueRepository,
      world.ids,
      InMemoryUnitOfWork(),
    );
    revoke = RevokeBlockAcquired(world.acquisitions, InMemoryUnitOfWork());
  });

  Future<Result<dynamic>> markBlock({
    String student = 's1',
    String block = 'a',
    DateTime? date,
    DateTime? today,
  }) => mark(
    studentId: StudentId(student),
    blockId: block,
    date: date ?? day(5),
    today: today ?? day(10),
  );

  group('MarkBlockAcquired', () {
    test(
      'stores the placement with the day and the placement source',
      () async {
        final acquisition = ok(
          await mark(
            studentId: _student,
            blockId: 'a',
            date: DateTime(2026, 10, 5, 14, 30),
            today: day(10),
          ),
        );

        expect(acquisition.id.value, 'id-1');
        expect(acquisition.blockId, 'a');
        expect(acquisition.date, day(5));
        expect(acquisition.source, AcquisitionSource.placement);
        expect(await world.acquisitions.forStudent(_student), [acquisition]);
      },
    );

    test('accepts today', () async {
      expect(ok(await markBlock(date: day(10))), isNotNull);
    });

    test('refuses an unknown student', () async {
      final failure = err(await markBlock(student: 'ghost'));

      expect(failure, isA<NotFound>().having((e) => e.kind, 'kind', 'student'));
      expect(await world.acquisitions.all(), isEmpty);
    });

    test('refuses a block outside the catalogue', () async {
      expect(codeOf(await markBlock(block: 'zzz')), InvariantCode.unknownBlock);
      expect(await world.acquisitions.all(), isEmpty);
    });

    test('refuses a date in the future', () async {
      expect(
        codeOf(await markBlock(date: day(11))),
        InvariantCode.dateInFuture,
      );
      expect(await world.acquisitions.all(), isEmpty);
    });

    test('refuses a second marker on the same block of the student', () async {
      ok(await markBlock());

      expect(
        codeOf(await markBlock(date: day(6))),
        InvariantCode.blockAlreadyAcquired,
      );
      expect(await world.acquisitions.forStudent(_student), hasLength(1));
    });

    test('reads the markers inside the unit of work', () async {
      final repository = _RecordsReads();
      final guarded = MarkBlockAcquired(
        world.students,
        repository,
        world.catalogueRepository,
        world.ids,
        repository.unitOfWork,
      );

      ok(
        await guarded(
          studentId: _student,
          blockId: 'a',
          date: day(5),
          today: day(10),
        ),
      );

      expect(repository.readInside, [true]);
      expect(repository.writtenInside, [true]);
    });

    test('accepts the same block for another student', () async {
      ok(await markBlock());

      expect(ok(await markBlock(student: 's2')), isNotNull);
    });

    test('accepts the block again once the marker is removed', () async {
      ok(await markBlock());
      ok(await revoke(studentId: _student, blockId: 'a'));

      expect(ok(await markBlock(date: day(6))), isNotNull);
    });
  });

  group('RevokeBlockAcquired', () {
    test('removes the marker of the block', () async {
      ok(await markBlock());
      ok(await markBlock(block: 'b'));

      ok(await revoke(studentId: _student, blockId: 'a'));

      final left = await world.acquisitions.forStudent(_student);
      expect(left.map((a) => a.blockId), ['b']);
    });

    test('refuses when the block is not marked', () async {
      final failure = err(await revoke(studentId: _student, blockId: 'a'));

      expect(
        failure,
        isA<NotFound>().having((e) => e.kind, 'kind', 'acquisition'),
      );
    });

    test('leaves the markers of other students', () async {
      ok(await markBlock(student: 's2'));

      final failure = err(await revoke(studentId: _student, blockId: 'a'));

      expect(failure, isA<NotFound>());
      expect(await world.acquisitions.all(), hasLength(1));
    });

    test('reads the markers inside the unit of work', () async {
      final repository = _RecordsReads();
      await repository.add(acquisition('a'));
      repository.readInside.clear();
      repository.writtenInside.clear();
      final guarded = RevokeBlockAcquired(repository, repository.unitOfWork);

      ok(await guarded(studentId: _student, blockId: 'a'));

      expect(repository.readInside, [true]);
      expect(repository.writtenInside, [true]);
    });

    test('removes every marker of the block or none', () async {
      final repository = _FailsOnSecondDelete();
      await repository.add(acquisition('a'));
      await repository.add(acquisition('a', id: 'q2'));
      final failing = RevokeBlockAcquired(repository, InMemoryUnitOfWork());

      await expectLater(
        failing(studentId: _student, blockId: 'a'),
        throwsStateError,
      );

      expect(await repository.all(), hasLength(2));
    });
  });
}

/// Dépôt dont la deuxième suppression échoue (retrait partiel à annuler).
class _FailsOnSecondDelete extends InMemoryAcquisitionRepository {
  int _deletes = 0;

  @override
  Future<void> delete(AcquisitionId id) async {
    if (++_deletes == 2) throw StateError('suppression refusée');
    await super.delete(id);
  }
}

/// Dépôt qui note si ses lectures et écritures ont lieu dans l'unité de
/// travail (lecture, contrôle et écriture forment un tout).
class _RecordsReads extends InMemoryAcquisitionRepository {
  _RecordsReads() {
    unitOfWork = _TrackingUnitOfWork(
      () => _inside = true,
      () => _inside = false,
    );
  }

  late final UnitOfWork unitOfWork;
  bool _inside = false;
  final readInside = <bool>[];
  final writtenInside = <bool>[];

  @override
  Future<List<BlockAcquisition>> forStudent(StudentId id) {
    readInside.add(_inside);
    return super.forStudent(id);
  }

  @override
  Future<void> add(BlockAcquisition acquisition) {
    writtenInside.add(_inside);
    return super.add(acquisition);
  }

  @override
  Future<void> delete(AcquisitionId id) {
    writtenInside.add(_inside);
    return super.delete(id);
  }
}

class _TrackingUnitOfWork implements UnitOfWork {
  _TrackingUnitOfWork(this._enter, this._leave);

  final void Function() _enter;
  final void Function() _leave;

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    _enter();
    try {
      return await body();
    } finally {
      _leave();
    }
  }
}
