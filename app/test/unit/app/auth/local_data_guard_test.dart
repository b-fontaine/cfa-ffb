import 'dart:async';

import 'package:billard_cfa/app/auth/local_data_guard.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/persistence/local_data_cache.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryLocalDataCache cache;
  late InMemoryKeyValueStore store;
  late InMemoryPendingWritesProbe sdk;
  late SendTracker sends;
  late LocalDataGuard guard;

  setUp(() {
    cache = InMemoryLocalDataCache();
    store = InMemoryKeyValueStore();
    sdk = InMemoryPendingWritesProbe();
    sends = SendTracker(sdk);
    guard = LocalDataGuard.withTiming(
      cache,
      store,
      sends,
      clearedElsewhereWithin: const Duration(milliseconds: 100),
      pollEvery: const Duration(milliseconds: 10),
    );
  });

  group('claim', () {
    test('the first account takes the cache, nothing to clear', () async {
      expect(await guard.claim('u1'), isFalse);

      expect(store.entries[LocalDataGuard.ownerKey], 'u1');
      expect(cache.clears, 0);
    });

    test('the same account again keeps its cache', () async {
      await guard.claim('u1');

      expect(await guard.claim('u1'), isFalse);

      expect(cache.clears, 0);
    });

    test('another account clears the cache before taking it over', () async {
      await guard.claim('u1');

      expect(await guard.claim('u2'), isTrue);

      expect(cache.clears, 1);
      expect(store.entries[LocalDataGuard.ownerKey], 'u2');
    });

    test('a failed clearing raises and keeps the previous owner: nothing '
        'is served to the new account', () async {
      await guard.claim('u1');
      cache.clearFailure = const FormatException('disque');

      await expectLater(guard.claim('u2'), throwsFormatException);

      expect(store.entries[LocalDataGuard.ownerKey], 'u1');
    });
  });

  group('release', () {
    test('clears the cache and forgets its owner', () async {
      await guard.claim('u1');

      await guard.release();

      expect(cache.clears, 1);
      expect(store.entries, isNot(contains(LocalDataGuard.ownerKey)));
    });

    test('without an owner there is nothing to clear', () async {
      await guard.release();

      expect(cache.clears, 0);
    });

    test('a failed clearing raises and keeps the owner, so the next account '
        'clears again', () async {
      await guard.claim('u1');
      cache.clearFailure = const FormatException('disque');

      await expectLater(guard.release(), throwsFormatException);

      expect(store.entries[LocalDataGuard.ownerKey], 'u1');
      cache.clearFailure = null;
      expect(await guard.claim('u2'), isTrue);
      expect(cache.clears, 1);
    });
  });

  group('pending erasure (a clearing that failed at sign-out)', () {
    test('a failed release leaves a pending mark that holds no personal '
        'data', () async {
      await guard.claim('u1');
      cache.clearFailure = const FormatException('disque');

      await expectLater(guard.release(), throwsFormatException);

      expect(await guard.erasurePending(), isTrue);
      expect(store.entries[LocalDataGuard.erasurePendingKey], isNot('u1'));
      expect(
        store.entries[LocalDataGuard.erasurePendingKey],
        isNot(contains('u1')),
      );
    });

    test('a successful release leaves no mark', () async {
      await guard.claim('u1');

      await guard.release();

      expect(await guard.erasurePending(), isFalse);
      expect(store.entries, isNot(contains(LocalDataGuard.erasurePendingKey)));
    });

    test('settling clears the cache, forgets the owner and the mark, and '
        'says it cleared', () async {
      await guard.claim('u1');
      cache.clearFailure = const FormatException('disque');
      await expectLater(guard.release(), throwsFormatException);
      cache.clearFailure = null;

      expect(await guard.settleErasure(), isTrue);

      expect(cache.clears, 1);
      expect(await guard.erasurePending(), isFalse);
      expect(store.entries, isNot(contains(LocalDataGuard.ownerKey)));
    });

    test('settling with nothing pending does not touch the cache', () async {
      await guard.claim('u1');

      expect(await guard.settleErasure(), isFalse);

      expect(cache.clears, 0);
      expect(store.entries[LocalDataGuard.ownerKey], 'u1');
    });

    test('a settling that fails again raises and keeps the mark', () async {
      await guard.claim('u1');
      cache.clearFailure = const FormatException('disque');
      await expectLater(guard.release(), throwsFormatException);

      await expectLater(guard.settleErasure(), throwsFormatException);

      expect(await guard.erasurePending(), isTrue);
    });

    test('the SAME account signing in again still gets a cleared cache: '
        'the mark outranks the owner', () async {
      await guard.claim('u1');
      cache.clearFailure = const FormatException('disque');
      await expectLater(guard.release(), throwsFormatException);
      cache.clearFailure = null;

      expect(await guard.claim('u1'), isTrue);

      expect(cache.clears, 1);
      expect(await guard.erasurePending(), isFalse);
      expect(store.entries[LocalDataGuard.ownerKey], 'u1');
    });

    test('another account cannot be served while the clearing keeps '
        'failing', () async {
      await guard.claim('u1');
      cache.clearFailure = const FormatException('disque');
      await expectLater(guard.release(), throwsFormatException);

      await expectLater(guard.claim('u2'), throwsFormatException);

      expect(store.entries[LocalDataGuard.ownerKey], 'u1');
      expect(await guard.erasurePending(), isTrue);
    });

    test(
      'a mark without a recorded owner still clears before any claim',
      () async {
        await store.write(LocalDataGuard.erasurePendingKey, '1');

        expect(await guard.claim('u1'), isTrue);

        expect(cache.clears, 1);
        expect(await guard.erasurePending(), isFalse);
        expect(store.entries[LocalDataGuard.ownerKey], 'u1');
      },
    );

    test(
      'the mark holds no personal data: one constant, no account id',
      () async {
        await guard.claim('u1');
        await expectLater(
          Future.sync(() async {
            cache.clearFailure = const FormatException('disque');
            await guard.release();
          }),
          throwsFormatException,
        );

        expect(store.entries[LocalDataGuard.erasurePendingKey], '1');
        for (final entry in store.entries.entries) {
          if (entry.key == LocalDataGuard.ownerKey) continue;
          expect(entry.value, isNot(contains('u1')), reason: entry.key);
        }
      },
    );

    test('a mark without an owner is still settled', () async {
      await store.write(LocalDataGuard.erasurePendingKey, '1');

      expect(await guard.settleErasure(), isTrue);

      expect(cache.clears, 1);
    });
  });

  test('unsent writes are the sends still waiting for the server', () async {
    expect(await guard.hasUnsentWrites(), isFalse);

    sends.track(Future<void>.delayed(const Duration(days: 1)));

    expect(await guard.hasUnsentWrites(), isTrue);
  });

  test('unsent writes queued in the SDK before a restart count too: the '
      'in-memory counter knows nothing of them', () async {
    sdk.hold();
    expect(sends.pending, 0);

    expect(await guard.hasUnsentWrites(), isTrue);

    sdk.flush();
    expect(await guard.hasUnsentWrites(), isFalse);
  });

  group('clearedElsewhere', () {
    test('an owner already forgotten: cleared at once', () async {
      expect(await guard.clearedElsewhere(), isTrue);
    });

    test('an owner forgotten while waiting: cleared', () async {
      await guard.claim('u1');
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 40),
          () => store.remove(LocalDataGuard.ownerKey),
        ),
      );

      expect(await guard.clearedElsewhere(), isTrue);
    });

    test('an owner that stays: not cleared, after the delay', () async {
      await guard.claim('u1');

      expect(await guard.clearedElsewhere(), isFalse);
    });

    test('a stop that turns true during the read wins over the vanished '
        "owner: the account came back, this is not the other tab's "
        'clearing', () async {
      var calls = 0;

      final cleared = await guard.clearedElsewhere(stop: () => ++calls > 1);

      expect(cleared, isFalse);
    });

    test('stop ends the wait early', () async {
      await guard.claim('u1');

      expect(await guard.clearedElsewhere(stop: () => true), isFalse);
    });
  });

  test('reopen puts the document store back in service', () async {
    await guard.reopen();

    expect(cache.reopens, 1);
  });
}
