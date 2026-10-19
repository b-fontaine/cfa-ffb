import 'dart:async';

import 'package:billard_cfa/shared/persistence/change_feed.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/stream_log.dart';

void main() {
  group('watchRead', () {
    late StreamController<void> changes;
    late List<int> source;
    var reads = 0;

    setUp(() {
      changes = StreamController<void>.broadcast(sync: true);
      source = [1];
      reads = 0;
    });

    tearDown(() => changes.close());

    Future<List<int>> read() async {
      reads++;
      return List.of(source);
    }

    test('reads at once, then at every change', () async {
      final log = StreamLog(watchRead(changes.stream, read));
      await log.settle();

      source = [1, 2];
      changes.add(null);
      await log.settle();

      expect(log.values, [
        [1],
        [1, 2],
      ]);
      await log.cancel();
    });

    test('never delivers the same state twice in a row', () async {
      final log = StreamLog(watchRead(changes.stream, read));
      await log.settle();

      changes
        ..add(null)
        ..add(null);
      await log.settle();

      expect(log.values, hasLength(1));
      await log.cancel();
    });

    test('changes during a read are folded into one more read', () async {
      final gate = Completer<void>();
      var calls = 0;
      final log = StreamLog(
        watchRead(changes.stream, () async {
          calls++;
          if (calls == 1) await gate.future;
          return calls;
        }),
      );
      await pumpEventQueue();

      changes
        ..add(null)
        ..add(null)
        ..add(null);
      await pumpEventQueue();
      expect(calls, 1, reason: 'jamais deux lectures en parallèle');
      gate.complete();
      await log.settle();

      expect(calls, 2);
      expect(log.values, [1, 2]);
      await log.cancel();
    });

    test('a failing read is an error on the stream, which goes on', () async {
      var failing = true;
      final log = StreamLog(
        watchRead(changes.stream, () async {
          if (failing) throw StateError('lecture');
          return 7;
        }),
      );
      await log.settle();
      expect(log.errors, hasLength(1));

      failing = false;
      changes.add(null);
      await log.settle();

      expect(log.values, [7]);
      expect(log.done, isFalse);
      await log.cancel();
    });

    test('cancelling stops listening to the changes', () async {
      final log = StreamLog(watchRead(changes.stream, read));
      await log.settle();
      await log.cancel();
      final before = reads;

      changes.add(null);
      await pumpEventQueue();

      expect(changes.hasListener, isFalse);
      expect(reads, before);
    });
  });

  group('sameState', () {
    test('lists are compared element by element', () {
      expect(sameState([1, 2], [1, 2]), isTrue);
      expect(sameState([1, 2], [2, 1]), isFalse);
      expect(sameState([1], [1, 2]), isFalse);
    });

    test('anything else by equality', () {
      expect(sameState('a', 'a'), isTrue);
      expect(sameState(null, null), isTrue);
      expect(sameState(1, 2), isFalse);
    });
  });

  group('ObservedMap', () {
    test('announces each change outside a unit of work', () async {
      final map = ObservedMap<String, int>();
      var announced = 0;
      final subscription = map.changes.listen((_) => announced++);

      map
        ..['a'] = 1
        ..remove('a')
        ..clear();

      expect(announced, 3);
      await subscription.cancel();
    });

    test('behaves as a map', () {
      final map = ObservedMap<String, int>()
        ..['a'] = 1
        ..['b'] = 2;

      expect(map.keys, ['a', 'b']);
      expect(map['a'], 1);
      expect(map.remove('a'), 1);
      expect(map.length, 1);
    });

    test('inside a unit of work, one announcement at the end, and a watcher '
        'never sees the unit half applied', () async {
      final map = ObservedMap<String, int>();
      final log = StreamLog(map.watch(() async => Map.of(map)));
      await log.settle();

      await InMemoryJournal().run(() async {
        map['a'] = 1;
        await pumpEventQueue();
        map['b'] = 2;
        await pumpEventQueue();
        expect(log.values, hasLength(1), reason: 'rien avant la fin');
      });
      await log.settle();

      expect(log.values, [
        <String, int>{},
        {'a': 1, 'b': 2},
      ]);
      await log.cancel();
    });

    test(
      'a unit that fails is rolled back and a watcher never saw it',
      () async {
        final map = ObservedMap<String, int>()..journaledPut('kept', 1);
        final log = StreamLog(map.watch(() async => Map.of(map)));
        await log.settle();

        await expectLater(
          InMemoryJournal().run(() async {
            map.journaledPut('lost', 2);
            await pumpEventQueue();
            throw StateError('échec');
          }),
          throwsStateError,
        );
        await log.settle();

        expect(log.values.every((state) => !state.containsKey('lost')), isTrue);
        expect(log.last, {'kept': 1});
        await log.cancel();
      },
    );

    test('nested units announce once, when the outermost one ends', () async {
      final map = ObservedMap<String, int>();
      var announced = 0;
      final subscription = map.changes.listen((_) => announced++);

      await InMemoryJournal().run(() async {
        await InMemoryJournal().run(() async {
          map['a'] = 1;
        });
        expect(announced, 0);
      });

      expect(announced, 1);
      await subscription.cancel();
    });
  });
}
