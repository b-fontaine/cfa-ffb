import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = 'clubs/c1/students/a';

Fields _fieldsOf(WriteOp operation) => switch (operation) {
  SetOp(:final fields) || UpdateOp(:final fields) => fields,
  DeleteOp() => throw StateError('a delete has no fields'),
};

void main() {
  group('PendingWrites.add', () {
    test('a plain set after a merge set replaces the whole document', () {
      final pending = PendingWrites()
        ..add(const SetOp(_path, {'a': 1, 'b': 2}, merge: true))
        ..add(const SetOp(_path, {'c': 3}));

      final operation = pending.operations.single as SetOp;
      expect(operation.merge, isFalse);
      expect(operation.fields, {'c': 3});
    });

    test('a merge set after a set merges the fields and keeps the kind', () {
      final pending = PendingWrites()
        ..add(const SetOp(_path, {'a': 1, 'b': 2}))
        ..add(const SetOp(_path, {'b': 5, 'c': 3}, merge: true));

      final operation = pending.operations.single as SetOp;
      expect(operation.merge, isFalse);
      expect(operation.fields, {'a': 1, 'b': 5, 'c': 3});
    });

    test(
      'an update after an update stays an update requiring the document',
      () {
        final pending = PendingWrites()
          ..add(const UpdateOp(_path, {'a': 1}))
          ..add(const UpdateOp(_path, {'b': 2}));

        final operation = pending.operations.single;
        expect(operation, isA<UpdateOp>());
        expect(_fieldsOf(operation), {'a': 1, 'b': 2});
      },
    );

    test('an update after a delete fails with notFound', () {
      final pending = PendingWrites()..add(const DeleteOp(_path));

      expect(
        () => pending.add(const UpdateOp(_path, {'a': 1})),
        throwsA(
          isA<StoreFailure>().having(
            (failure) => failure.code,
            'code',
            StoreFailureCode.notFound,
          ),
        ),
      );
    });

    test('a set after a delete leaves only the fields of the set', () {
      final pending = PendingWrites()
        ..add(const DeleteOp(_path))
        ..add(const SetOp(_path, {'a': 1}));

      final operation = pending.operations.single as SetOp;
      expect(operation.fields, {'a': 1});
    });

    test('a merge set after a delete is that set, nothing of before', () {
      final pending = PendingWrites()
        ..add(const SetOp(_path, {'old': 1}))
        ..add(const DeleteOp(_path))
        ..add(const SetOp(_path, {'a': 1}, merge: true));

      final operation = pending.operations.single as SetOp;
      expect(operation.fields, {'a': 1});
    });

    test('a delete after any write is a delete', () {
      final pending = PendingWrites()
        ..add(const SetOp(_path, {'a': 1}))
        ..add(const DeleteOp(_path));

      expect(pending.operations.single, isA<DeleteOp>());
    });

    test('two removals of one field remove both sets of values', () {
      final pending = PendingWrites()
        ..add(
          const UpdateOp(_path, {
            'ids': ArrayRemove(['a']),
          }),
        )
        ..add(
          const UpdateOp(_path, {
            'ids': ArrayRemove(['b']),
          }),
        );

      final ids = _fieldsOf(pending.operations.single)['ids']! as ArrayRemove;
      expect(ids.values, ['a', 'b']);
    });

    test('two unions of one field add both without duplicates', () {
      final pending = PendingWrites()
        ..add(
          const UpdateOp(_path, {
            'ids': ArrayUnion(['a', 'b']),
          }),
        )
        ..add(
          const UpdateOp(_path, {
            'ids': ArrayUnion(['b', 'c']),
          }),
        );

      final ids = _fieldsOf(pending.operations.single)['ids']! as ArrayUnion;
      expect(ids.values, ['a', 'b', 'c']);
    });

    test('a union after a removal of one field is refused', () {
      final pending = PendingWrites()
        ..add(
          const UpdateOp(_path, {
            'ids': ArrayRemove(['a']),
          }),
        );

      expect(
        () => pending.add(
          const UpdateOp(_path, {
            'ids': ArrayUnion(['a']),
          }),
        ),
        throwsA(isA<StoreFailure>()),
      );
    });

    test('a union after a plain list adds to it, a removal takes from it', () {
      final union = PendingWrites()
        ..add(
          const SetOp(_path, {
            'ids': ['a', 'b'],
          }),
        )
        ..add(
          const UpdateOp(_path, {
            'ids': ArrayUnion(['b', 'c']),
          }),
        );
      final removal = PendingWrites()
        ..add(
          const SetOp(_path, {
            'ids': ['a', 'b'],
          }),
        )
        ..add(
          const UpdateOp(_path, {
            'ids': ArrayRemove(['a']),
          }),
        );

      expect(_fieldsOf(union.operations.single)['ids'], ['a', 'b', 'c']);
      expect(_fieldsOf(removal.operations.single)['ids'], ['b']);
    });

    test('keeps the order of the first write of each document', () {
      final pending = PendingWrites()
        ..add(const SetOp('clubs/c1/students/b', {'n': 1}))
        ..add(const SetOp('clubs/c1/students/a', {'n': 1}))
        ..add(const SetOp('clubs/c1/students/b', {'n': 2}));

      expect(
        [for (final operation in pending.operations) operation.path],
        ['clubs/c1/students/b', 'clubs/c1/students/a'],
      );
    });
  });

  group('PendingWrites.overlay', () {
    test('rends the stored state when nothing is pending', () {
      expect(PendingWrites().overlay(_path, {'a': 1}), {'a': 1});
      expect(PendingWrites().overlay(_path, null), isNull);
    });

    test('a plain set replaces the stored document', () {
      final pending = PendingWrites()..add(const SetOp(_path, {'c': 3}));

      expect(pending.overlay(_path, {'a': 1}), {'c': 3});
    });

    test('a merge set keeps the stored fields, even from nothing', () {
      final pending = PendingWrites()
        ..add(const SetOp(_path, {'c': 3}, merge: true));

      expect(pending.overlay(_path, {'a': 1}), {'a': 1, 'c': 3});
      expect(pending.overlay(_path, null), {'c': 3});
    });

    test('an update merges into the stored document', () {
      final pending = PendingWrites()..add(const UpdateOp(_path, {'c': 3}));

      expect(pending.overlay(_path, {'a': 1}), {'a': 1, 'c': 3});
    });

    test('an update of an absent document gives null', () {
      final pending = PendingWrites()..add(const UpdateOp(_path, {'c': 3}));

      expect(pending.overlay(_path, null), isNull);
    });

    test('a delete gives null', () {
      final pending = PendingWrites()..add(const DeleteOp(_path));

      expect(pending.overlay(_path, {'a': 1}), isNull);
    });

    test('resolves array values against the stored state', () {
      final pending = PendingWrites()
        ..add(
          const UpdateOp(_path, {
            'ids': ArrayUnion(['b']),
            'gone': ArrayRemove(['x']),
          }),
        );

      expect(
        pending.overlay(_path, {
          'ids': ['a'],
          'gone': ['x', 'y'],
        }),
        {
          'ids': ['a', 'b'],
          'gone': ['y'],
        },
      );
    });

    test('replaces the server date by a local date', () {
      final pending = PendingWrites()
        ..add(const SetOp(_path, {'at': serverTimestamp}));

      expect(pending.overlay(_path, null)!['at'], isA<DateTime>());
    });

    test('only the document asked for is concerned', () {
      final pending = PendingWrites()..add(const DeleteOp(_path));

      expect(pending.overlay('clubs/c1/students/b', {'a': 1}), {'a': 1});
    });
  });
}
