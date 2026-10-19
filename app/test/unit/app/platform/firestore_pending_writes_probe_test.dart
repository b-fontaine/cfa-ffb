import 'dart:async';

import 'package:billard_cfa/app/platform/firestore_pending_writes_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const quick = Duration(milliseconds: 20);

  test('an empty queue answers at once: nothing pending', () async {
    final probe = FirestorePendingWritesProbe(
      waitForPendingWrites: () async {},
      timeout: quick,
    );

    expect(await probe.hasPending(), isFalse);
  });

  test('a queue the server does not drain in time is pending', () async {
    final probe = FirestorePendingWritesProbe(
      waitForPendingWrites: () => Completer<void>().future,
      timeout: quick,
    );

    expect(await probe.hasPending(), isTrue);
  });

  test('a SDK that is not reachable has nothing to lose', () async {
    final probe = FirestorePendingWritesProbe(
      waitForPendingWrites: () => throw StateError('no Firebase app'),
      timeout: quick,
    );

    expect(await probe.hasPending(), isFalse);
  });

  test('untilSent waits for the queue and never raises', () async {
    final queue = Completer<void>();
    final probe = FirestorePendingWritesProbe(
      waitForPendingWrites: () => queue.future,
      timeout: quick,
    );
    var done = false;
    final waiting = probe.untilSent().then((_) => done = true);

    await Future<void>.delayed(quick * 2);
    expect(done, isFalse);

    queue.completeError(StateError('terminated'));
    await waiting;
    expect(done, isTrue);
  });
}
