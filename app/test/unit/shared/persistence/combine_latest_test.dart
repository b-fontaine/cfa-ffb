import 'dart:async';

import 'package:billard_cfa/shared/persistence/combine_latest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/stream_log.dart';

void main() {
  late List<StreamController<int>> sources;
  late List<bool> cancelled;

  setUp(() {
    cancelled = [false, false, false];
    sources = [
      for (var i = 0; i < 3; i++)
        StreamController<int>(onCancel: () => cancelled[i] = true),
    ];
  });

  Stream<List<int>> combined(int count) =>
      combineLatest([for (var i = 0; i < count; i++) sources[i].stream]);

  test('waits for every source before the first state', () async {
    final log = StreamLog(combined(2));
    sources[0].add(1);
    await log.settle();
    expect(log.values, isEmpty);

    sources[1].add(10);
    await log.settle();

    expect(log.values, [
      [1, 10],
    ]);
    await log.cancel();
  });

  test('then emits the latest state of all on every change', () async {
    final log = StreamLog(combined(2));
    sources[0].add(1);
    sources[1].add(10);
    await log.settle();

    sources[0].add(2);
    await log.settle();
    sources[1].add(20);
    await log.settle();

    expect(log.values, [
      [1, 10],
      [2, 10],
      [2, 20],
    ]);
    await log.cancel();
  });

  test('no source gives one empty state', () async {
    final log = StreamLog(combineLatest<int>(const []));
    await log.settle();

    expect(log.values, [<int>[]]);
    expect(log.done, isTrue);
  });

  test('an error ends the combination and releases every source', () async {
    final log = StreamLog(combined(3));
    sources[0].add(1);
    sources[1].add(10);
    sources[2].add(100);
    await log.settle();

    sources[1].addError('refusé');
    await log.settle();

    expect(log.errors, ['refusé']);
    expect(log.done, isTrue);
    expect(cancelled, [true, true, true]);
  });

  test('cancelling releases every source', () async {
    final log = StreamLog(combined(3));
    await log.settle();

    await log.cancel();

    expect(cancelled, [true, true, true]);
  });

  test('ends when every source has ended, after their last states', () async {
    final log = StreamLog(combined(2));
    sources[0].add(1);
    sources[1].add(10);
    await sources[0].close();
    await log.settle();
    expect(log.done, isFalse);

    sources[1].add(20);
    await sources[1].close();
    await log.settle();

    expect(log.last, [1, 20]);
    expect(log.done, isTrue);
  });
}
