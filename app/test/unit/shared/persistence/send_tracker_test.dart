import 'dart:async';

import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts the batches sent and not yet acknowledged', () async {
    final tracker = SendTracker();
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
    final tracker = SendTracker();
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
    final tracker = SendTracker();
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
    final tracker = SendTracker();
    final send = Completer<void>();

    tracker.track(send.future);
    send.completeError(StateError('boom'));
    await pumpEventQueue();

    expect(tracker.lastFailure?.code, StoreFailureCode.other);
  });
}
