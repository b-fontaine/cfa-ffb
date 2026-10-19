import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/device_document_store.dart';
import '../../support/stream_log.dart';

/// Le double d'appareil sert aux scénarios multi-appareils : ses règles sont
/// vérifiées ici pour que les scénarios disent vrai.
void main() {
  late InMemoryDocumentStore server;
  late DeviceDocumentStore device;

  setUp(() {
    server = InMemoryDocumentStore();
    device = DeviceDocumentStore(server);
  });

  test('online, it is the server', () async {
    await device.commit([
      const SetOp('clubs/c1/students/s1', {'n': 1}),
    ]);

    expect((await server.get('clubs/c1/students/s1'))!.fields['n'], 1);
    expect(await device.list('clubs/c1/students'), hasLength(1));
  });

  test('offline, server reads fail as unavailable', () async {
    device.goOffline();

    await expectLater(
      device.get('clubs/c1/students/s1'),
      throwsA(
        isA<StoreFailure>().having(
          (e) => e.code,
          'code',
          StoreFailureCode.unavailable,
        ),
      ),
    );
    await expectLater(device.list('a'), throwsA(isA<StoreFailure>()));
    await expectLater(
      device.createIfAbsent('a/b', {'n': 1}),
      throwsA(isA<StoreFailure>()),
    );
    expect(await device.peek('a/b'), isNull);
  });

  test('offline writes wait in order and go out on reconnection', () async {
    device.goOffline();

    await device.commit([
      const SetOp('a/1', {'n': 1}),
    ]);
    await device.commit([
      const UpdateOp('a/1', {'n': 2}),
    ]);

    expect(device.queuedBatches, 2);
    expect(server.read('a/1'), isNull);

    await device.goOnline();

    expect(server.read('a/1'), {'n': 2});
    expect(device.queuedBatches, 0);
  });

  test(
    'offline, a watcher keeps its state, gets the latest on return',
    () async {
      final log = StreamLog(device.watchDocument('a/1'));
      await log.settle();

      device.goOffline();
      server
        ..seed('a/1', {'n': 1})
        ..seed('a/1', {'n': 2});
      await log.settle();
      expect(log.values, hasLength(1));

      await device.goOnline();
      await log.settle();

      expect(log.values, hasLength(2));
      expect(log.last.document!.fields['n'], 2);
      await log.cancel();
      expect(server.activeWatchers, 0);
    },
  );

  test('a refusal that arrives offline is delivered on reconnection', () async {
    final log = StreamLog(device.watchCollection('clubs/c1/students'));
    await log.settle();

    device.goOffline();
    server.revoke('clubs/c1/');
    await log.settle();
    expect(log.errors, isEmpty);

    await device.goOnline();
    await log.settle();

    expect(log.errors, hasLength(1));
    expect(log.done, isTrue);
  });
}
