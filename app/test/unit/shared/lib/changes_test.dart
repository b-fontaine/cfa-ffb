import 'dart:async';

import 'package:billard_cfa/shared/lib/changes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/stream_log.dart';

void main() {
  late StreamController<List<int>> first;
  late StreamController<String> second;
  var firstCancelled = false;
  var secondCancelled = false;

  setUp(() {
    firstCancelled = secondCancelled = false;
    first = StreamController<List<int>>(onCancel: () => firstCancelled = true);
    second = StreamController<String>(onCancel: () => secondCancelled = true);
  });

  test('the first state of each source is a baseline, not a change', () async {
    final log = StreamLog(changesOf([first.stream, second.stream]));
    first.add([1]);
    second.add('a');
    await log.settle();

    expect(log.values, isEmpty);
    await log.cancel();
  });

  test('every later state of any source is one change', () async {
    final log = StreamLog(changesOf([first.stream, second.stream]));
    first.add([1]);
    second.add('a');
    await log.settle();

    first.add([1, 2]);
    second.add('b');
    first.add([]);
    await log.settle();

    expect(log.values, hasLength(3));
    await log.cancel();
  });

  test('an error is forwarded and the other sources keep going', () async {
    final log = StreamLog(changesOf([first.stream, second.stream]));
    first.add([1]);
    second.add('a');
    await log.settle();

    first.addError('refusé');
    second.add('b');
    await log.settle();

    expect(log.errors, ['refusé']);
    expect(log.values, hasLength(1));
    expect(log.done, isFalse);
    await log.cancel();
  });

  test('cancelling cancels every source', () async {
    final log = StreamLog(changesOf([first.stream, second.stream]));
    await log.settle();

    await log.cancel();

    expect(firstCancelled, isTrue);
    expect(secondCancelled, isTrue);
  });

  test('it ends when every source has ended', () async {
    final log = StreamLog(changesOf([first.stream, second.stream]));
    await first.close();
    await log.settle();
    expect(log.done, isFalse);

    await second.close();
    await log.settle();

    expect(log.done, isTrue);
  });

  test('no source at all ends at once', () async {
    final log = StreamLog(changesOf(const []));
    await log.settle();

    expect(log.done, isTrue);
  });
}
