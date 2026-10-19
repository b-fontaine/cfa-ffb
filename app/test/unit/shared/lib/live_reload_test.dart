import 'dart:async';

import 'package:billard_cfa/shared/lib/live_reload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<StreamController<void>> opened;
  late int reloads;
  late Completer<void>? gate;
  late LiveReload live;

  Stream<void> open() {
    final controller = StreamController<void>(onCancel: () {});
    opened.add(controller);
    return controller.stream;
  }

  setUp(() {
    opened = [];
    reloads = 0;
    gate = null;
    live = LiveReload(
      open: open,
      reload: () async {
        reloads++;
        await gate?.future;
      },
    );
  });

  tearDown(() => live.stop());

  test('nothing is read until a change arrives', () async {
    live.start();
    await pumpEventQueue();

    expect(reloads, 0);
    expect(live.isActive, isTrue);
  });

  test('a change reloads once', () async {
    live.start();
    opened.single.add(null);
    await pumpEventQueue();

    expect(reloads, 1);
  });

  test('starting twice never opens a second subscription', () async {
    live
      ..start()
      ..start();
    await pumpEventQueue();

    expect(opened.where((c) => c.hasListener), hasLength(1));
    opened.last.add(null);
    await pumpEventQueue();
    expect(reloads, 1);
  });

  test(
    'restarting replaces the subscription and releases the old one',
    () async {
      live
        ..start()
        ..restart();
      await pumpEventQueue();

      expect(opened, hasLength(2));
      expect(opened.first.hasListener, isFalse);
      expect(opened.last.hasListener, isTrue);
    },
  );

  test('changes during a reload are folded into one more reload', () async {
    gate = Completer<void>();
    live.start();
    opened.single.add(null);
    await pumpEventQueue();
    expect(reloads, 1);

    opened.single
      ..add(null)
      ..add(null)
      ..add(null);
    await pumpEventQueue();
    expect(reloads, 1, reason: 'jamais deux lectures en parallèle');

    gate!.complete();
    await pumpEventQueue();

    expect(reloads, 2);
  });

  test(
    'an error of the changes also reloads, so that the failure shows',
    () async {
      live.start();
      opened.single.addError('refusé');
      await pumpEventQueue();

      expect(reloads, 1);
      expect(live.isActive, isTrue);
    },
  );

  test('a reload that throws does not stop the watch', () async {
    var failing = true;
    live = LiveReload(
      open: open,
      reload: () async {
        reloads++;
        if (failing) throw StateError('lecture');
      },
    )..start();
    opened.last.add(null);
    await pumpEventQueue();
    failing = false;
    opened.last.add(null);
    await pumpEventQueue();

    expect(reloads, 2);
    await live.stop();
  });

  test('stopping cancels the subscription and ignores later changes', () async {
    live.start();
    final controller = opened.single;
    await live.stop();

    expect(controller.hasListener, isFalse);
    expect(live.isActive, isFalse);
    expect(reloads, 0);
  });

  test('a reload running when it stops is not followed by another', () async {
    gate = Completer<void>();
    live.start();
    opened.single.add(null);
    await pumpEventQueue();
    opened.single.add(null);
    await pumpEventQueue();

    await live.stop();
    gate!.complete();
    await pumpEventQueue();

    expect(reloads, 1);
  });

  test('it can start again after a stop', () async {
    live.start();
    await live.stop();
    live.start();
    opened.last.add(null);
    await pumpEventQueue();

    expect(reloads, 1);
  });

  test(
    'an error after data ends the subscription: the next read reopens it',
    () async {
      live.start();
      opened.single.add(null);
      await pumpEventQueue();

      opened.single.addError('scope-changed');
      await pumpEventQueue();

      expect(reloads, 2);
      expect(opened, hasLength(2));
      expect(opened.last.hasListener, isTrue);
      opened.last.add(null);
      await pumpEventQueue();
      expect(reloads, 3);
    },
  );

  test('the reopening waits for the reload that follows the error', () async {
    live.start();
    opened.single.add(null);
    await pumpEventQueue();
    gate = Completer<void>();

    opened.single.addError('scope-changed');
    await pumpEventQueue();
    expect(opened, hasLength(1));

    gate!.complete();
    await pumpEventQueue();
    expect(opened, hasLength(2));
  });

  test('an error on a fresh stream reopens it, without data', () async {
    live.start();
    opened.single.addError('scope-changed');
    await pumpEventQueue();

    expect(reloads, 1);
    expect(opened, hasLength(2));
  });

  test('a stream that keeps failing is reopened once, not in a loop', () async {
    live.start();
    opened.single.addError('refusé');
    await pumpEventQueue();
    opened.last.addError('refusé');
    await pumpEventQueue();
    opened.last.addError('refusé');
    await pumpEventQueue();

    expect(opened, hasLength(2));
    expect(reloads, 3, reason: 'chaque erreur relit, une seule rouvre');
  });

  test('a datum received after a failure restores the trust: the next '
      'error reopens again', () async {
    live.start();
    opened.single.addError('refusé');
    await pumpEventQueue();
    expect(opened, hasLength(2));

    opened.last.add(null);
    await pumpEventQueue();
    opened.last.addError('scope-changed');
    await pumpEventQueue();

    expect(opened, hasLength(3));
    expect(opened.last.hasListener, isTrue);
  });

  test('restarting resets the guard: the next error reopens again', () async {
    live.start();
    opened.single.addError('refusé');
    await pumpEventQueue();
    opened.last.addError('refusé');
    await pumpEventQueue();
    expect(opened, hasLength(2));

    live.restart();
    await pumpEventQueue();
    expect(opened, hasLength(3));
    opened.last.addError('refusé');
    await pumpEventQueue();

    expect(opened, hasLength(4));
  });

  test('the guard is not reset by a reload nor by a reopening', () async {
    live.start();
    opened.single.addError('refusé');
    await pumpEventQueue();
    // Aucune donnée : ni la relecture ni la réouverture n'ont rendu la
    // confiance.
    opened.last.addError('refusé');
    await pumpEventQueue();
    opened.last.addError('refusé');
    await pumpEventQueue();

    expect(opened, hasLength(2));
  });
}
