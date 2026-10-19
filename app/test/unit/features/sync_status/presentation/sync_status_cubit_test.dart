import 'dart:async';

import 'package:billard_cfa/features/sync_status/domain/sync_state.dart';
import 'package:billard_cfa/features/sync_status/presentation/bloc/sync_status_cubit.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryPendingWritesProbe sdk;
  late SendTracker sends;
  late InMemoryConnectivityStatus network;
  late SyncStatusCubit cubit;

  setUp(() {
    sdk = InMemoryPendingWritesProbe();
    sends = SendTracker(sdk);
    network = InMemoryConnectivityStatus();
    cubit = SyncStatusCubit(sends, network);
    addTearDown(cubit.close);
  });

  Future<void> settle() => pumpEventQueue();

  test('starts up to date', () {
    expect(cubit.state, SyncState.upToDate);
  });

  test('starts from what the sources already say', () {
    final late = SyncStatusCubit(
      sends..track(Completer<void>().future),
      network..setOnline(value: false),
    );
    addTearDown(late.close);

    expect(late.state.phase, SyncPhase.pending);
    expect(late.state.offline, isTrue);
  });

  test('writes left in the SDK by a previous run show as pending, then '
      'clear once sent', () async {
    sdk.hold();
    final restarted = SyncStatusCubit(sends, network);
    addTearDown(restarted.close);
    await settle();

    expect(restarted.state.phase, SyncPhase.pending);

    sdk.flush();
    await settle();

    expect(restarted.state, SyncState.upToDate);
  });

  test('offline with nothing to send, then the network comes back', () async {
    network.setOnline(value: false);
    await settle();
    expect(cubit.state.phase, SyncPhase.offline);

    network.setOnline(value: true);
    await settle();

    expect(cubit.state, SyncState.upToDate);
  });

  test('a write waiting for the server is pending, then up to date once '
      'acknowledged', () async {
    final ack = Completer<void>();

    sends.track(ack.future);
    await settle();
    expect(cubit.state, const SyncState(phase: SyncPhase.pending, pending: 1));

    ack.complete();
    await settle();

    expect(cubit.state, SyncState.upToDate);
  });

  test('written offline, sent when the network returns', () async {
    final ack = Completer<void>();
    network.setOnline(value: false);
    sends.track(ack.future);
    await settle();
    expect(
      cubit.state,
      const SyncState(phase: SyncPhase.pending, pending: 1, offline: true),
    );

    network.setOnline(value: true);
    ack.complete();
    await settle();

    expect(cubit.state, SyncState.upToDate);
  });

  test(
    'a send refused later by the rules is reported until acknowledged',
    () async {
      final ack = Completer<void>();
      sends.track(ack.future);

      ack.completeError(const StoreFailure(StoreFailureCode.permissionDenied));
      await settle();
      expect(cubit.state.phase, SyncPhase.failed);

      cubit.acknowledgeFailure();

      expect(cubit.state, SyncState.upToDate);
      expect(sends.hasFailure, isFalse);
    },
  );

  test('stops listening once closed', () async {
    await cubit.close();

    sends.track(Future<void>.value());
    network.setOnline(value: false);
    await settle();

    expect(cubit.isClosed, isTrue);
  });
}
