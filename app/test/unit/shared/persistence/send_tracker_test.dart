import 'dart:async';

import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts the batches sent and not yet acknowledged', () async {
    final tracker = SendTracker(InMemoryPendingWritesProbe());
    final first = Completer<void>();
    final second = Completer<void>();

    tracker
      ..track(first.future)
      ..track(second.future);
    expect(tracker.pending, 2);

    first.complete();
    await pumpEventQueue();
    expect(tracker.pending, 1);

    second.complete();
    await pumpEventQueue();
    expect(tracker.pending, 0);
    expect(tracker.lastFailure, isNull);
  });

  test('announces every change of the count', () async {
    final tracker = SendTracker(InMemoryPendingWritesProbe());
    final changes = <int>[];
    final subscription = tracker.pendingChanges.listen(changes.add);
    addTearDown(subscription.cancel);
    final send = Completer<void>();

    tracker.track(send.future);
    send.complete();
    await pumpEventQueue();

    expect(changes, [1, 0]);
  });

  test('keeps the failure of a refused sending, without throwing', () async {
    final tracker = SendTracker(InMemoryPendingWritesProbe());
    final send = Completer<void>();

    tracker.track(send.future);
    send.completeError(const StoreFailure(StoreFailureCode.permissionDenied));
    await pumpEventQueue();

    expect(tracker.pending, 0);
    expect(tracker.lastFailure?.code, StoreFailureCode.permissionDenied);

    tracker.clearFailure();
    expect(tracker.lastFailure, isNull);
  });

  test('keeps an unexpected error as an unknown failure', () async {
    final tracker = SendTracker(InMemoryPendingWritesProbe());
    final send = Completer<void>();

    tracker.track(send.future);
    send.completeError(StateError('boom'));
    await pumpEventQueue();

    expect(tracker.lastFailure?.code, StoreFailureCode.other);
  });

  group('writes already queued in the SDK (before a restart)', () {
    late InMemoryPendingWritesProbe sdk;
    late SendTracker tracker;

    setUp(() {
      sdk = InMemoryPendingWritesProbe();
      tracker = SendTracker(sdk);
    });

    test('a refresh turns them into one pending batch until the SDK has '
        'sent them', () async {
      sdk.hold();

      await tracker.refresh();
      expect(tracker.pending, 1);

      sdk.flush();
      await pumpEventQueue();
      expect(tracker.pending, 0);
      expect(tracker.hasFailure, isFalse);
    });

    test('an empty queue changes nothing', () async {
      await tracker.refresh();

      expect(tracker.pending, 0);
    });

    test('refreshing twice does not count the same queue twice', () async {
      sdk.hold();

      await tracker.refresh();
      await tracker.refresh();

      expect(tracker.pending, 1);
    });

    test('batches already tracked make the SDK question useless', () async {
      tracker.track(Completer<void>().future);

      await tracker.refresh();

      expect(sdk.probes, 0);
      expect(tracker.pending, 1);
    });

    test('hasUnsentWrites asks the SDK, not only the counter', () async {
      expect(await tracker.hasUnsentWrites(), isFalse);

      sdk.hold();

      expect(await tracker.hasUnsentWrites(), isTrue);
    });
  });
}
