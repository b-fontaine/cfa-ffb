import 'dart:async';

import 'package:billard_cfa/shared/persistence/relay_stream.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/stream_log.dart';

void main() {
  late StreamController<int> source;
  var cancelled = false;

  setUp(() {
    cancelled = false;
    source = StreamController<int>(onCancel: () => cancelled = true);
  });

  test('converts each event', () async {
    final log = StreamLog(
      relayStream<int, String>(source.stream, data: (n) => 'n$n'),
    );
    source
      ..add(1)
      ..add(2);
    await log.settle();

    expect(log.values, ['n1', 'n2']);
    await log.cancel();
  });

  test('cancelling the relay cancels the source', () async {
    final log = StreamLog(relayStream<int, int>(source.stream, data: (n) => n));
    await log.settle();

    await log.cancel();

    expect(cancelled, isTrue);
  });

  test('an error is translated, delivered once, then the relay ends', () async {
    final log = StreamLog(
      relayStream<int, int>(
        source.stream,
        data: (n) => n,
        error: (error) => 'traduit $error',
      ),
    );
    source
      ..add(1)
      ..addError('boom')
      ..add(2);
    await log.settle();

    expect(log.values, [1]);
    expect(log.errors, ['traduit boom']);
    expect(log.done, isTrue);
    expect(cancelled, isTrue);
  });

  test('a conversion that throws ends the relay like an error', () async {
    final log = StreamLog(
      relayStream<int, int>(
        source.stream,
        data: (n) => n == 2 ? throw const FormatException('mal formé') : n,
      ),
    );
    source
      ..add(1)
      ..add(2)
      ..add(3);
    await log.settle();

    expect(log.values, [1]);
    expect(log.errors.single, isA<FormatException>());
    expect(log.done, isTrue);
    expect(cancelled, isTrue);
  });

  test('an invalid relay delivers the invalid error before ending', () async {
    var valid = true;
    final log = StreamLog(
      relayStream<int, int>(
        source.stream,
        data: (n) => n,
        valid: () => valid,
        invalid: () => 'plus valide',
      ),
    );
    source.add(1);
    await log.settle();
    valid = false;
    source.add(2);
    await log.settle();

    expect(log.values, [1]);
    expect(log.errors, ['plus valide']);
    expect(log.done, isTrue);
    expect(cancelled, isTrue);
  });

  test('a recheck signal ends an invalid relay without any event', () async {
    var valid = true;
    final recheck = StreamController<void>.broadcast(sync: true);
    final log = StreamLog(
      relayStream<int, int>(
        source.stream,
        data: (n) => n,
        valid: () => valid,
        invalid: () => 'plus valide',
        recheck: recheck.stream,
      ),
    );
    await log.settle();

    recheck.add(null);
    expect(cancelled, isFalse, reason: 'encore valide : rien ne ferme');
    valid = false;
    recheck.add(null);

    expect(cancelled, isTrue, reason: 'fermé sans attendre un événement');
    await log.settle();
    expect(log.errors, ['plus valide']);
    expect(log.done, isTrue);
    expect(recheck.hasListener, isFalse);
  });

  test('cancelling the relay stops listening to the recheck signal', () async {
    final recheck = StreamController<void>.broadcast(sync: true);
    final log = StreamLog(
      relayStream<int, int>(
        source.stream,
        data: (n) => n,
        valid: () => true,
        recheck: recheck.stream,
      ),
    );
    await log.settle();
    expect(recheck.hasListener, isTrue);

    await log.cancel();

    expect(recheck.hasListener, isFalse);
  });

  test('the end of the source ends the relay', () async {
    final log = StreamLog(relayStream<int, int>(source.stream, data: (n) => n));
    await source.close();
    await log.settle();

    expect(log.done, isTrue);
  });

  test('pausing the subscriber pauses the source', () async {
    final received = <int>[];
    final subscription = relayStream<int, int>(
      source.stream,
      data: (n) => n,
    ).listen(received.add)..pause();
    source.add(1);
    await pumpEventQueue();
    expect(received, isEmpty);

    subscription.resume();
    await pumpEventQueue();
    expect(received, [1]);
    await subscription.cancel();
  });
}
