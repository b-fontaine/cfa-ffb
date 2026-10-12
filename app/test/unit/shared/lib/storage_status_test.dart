import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the in-memory implementation is volatile', () {
    expect(StorageImplementation.nativeFile.persistent, isTrue);
    expect(StorageImplementation.webOpfs.persistent, isTrue);
    expect(StorageImplementation.webIndexedDb.persistent, isTrue);
    expect(StorageImplementation.inMemory.persistent, isFalse);
  });

  test('the test status is persistent and can be made volatile', () {
    final status = InMemoryStorageStatus();

    expect(status.implementation.persistent, isTrue);
    expect(status.degradationReasons, isEmpty);

    status
      ..implementation = StorageImplementation.inMemory
      ..degradationReasons = ['opfs'];

    expect(status.implementation.persistent, isFalse);
    expect(status.degradationReasons, ['opfs']);
  });
}
