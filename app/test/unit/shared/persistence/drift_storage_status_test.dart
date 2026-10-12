import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:billard_cfa/shared/persistence/drift_storage_status.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

WasmDatabaseResult _result(
  WasmStorageImplementation chosen, [
  Set<MissingBrowserFeature> missing = const {},
]) => WasmDatabaseResult(
  DatabaseConnection(NativeDatabase.memory()),
  chosen,
  missing,
);

void main() {
  test('is a persistent native file until the browser says otherwise', () {
    final status = DriftStorageStatus();

    expect(status.implementation, StorageImplementation.nativeFile);
    expect(status.implementation.persistent, isTrue);
    expect(status.degradationReasons, isEmpty);
  });

  const expected = {
    WasmStorageImplementation.opfsShared: StorageImplementation.webOpfs,
    WasmStorageImplementation.opfsLocks: StorageImplementation.webOpfs,
    WasmStorageImplementation.sharedIndexedDb:
        StorageImplementation.webIndexedDb,
    WasmStorageImplementation.unsafeIndexedDb:
        StorageImplementation.webIndexedDb,
    WasmStorageImplementation.inMemory: StorageImplementation.inMemory,
  };
  expected.forEach((chosen, implementation) {
    test('maps ${chosen.name} to ${implementation.name}', () {
      expect(
        DriftStorageStatus.storageImplementationOf(chosen),
        implementation,
      );
    });
  });

  test('covers every storage chosen by drift', () {
    expect(expected.keys.toSet(), WasmStorageImplementation.values.toSet());
  });

  test('records a degraded web storage with the missing features', () {
    final status = DriftStorageStatus()
      ..recordWebResult(
        _result(WasmStorageImplementation.inMemory, {
          MissingBrowserFeature.indexedDb,
          MissingBrowserFeature.sharedWorkers,
        }),
      );

    expect(status.implementation, StorageImplementation.inMemory);
    expect(status.implementation.persistent, isFalse);
    expect(status.degradationReasons, ['indexedDb', 'sharedWorkers']);
  });

  test('records a reliable web storage without reasons', () {
    final status = DriftStorageStatus()
      ..recordWebResult(_result(WasmStorageImplementation.opfsShared));

    expect(status.implementation, StorageImplementation.webOpfs);
    expect(status.implementation.persistent, isTrue);
    expect(status.degradationReasons, isEmpty);
  });
}
