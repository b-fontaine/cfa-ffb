import 'dart:async';

import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_cubit.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _done = StaleMarkerPurgeResult(
  status: StaleMarkerPurgeStatus.completed,
  removed: 3,
);

void main() {
  test('starts idle', () {
    final cubit = StaleMarkersCubit(() async => _done);
    addTearDown(cubit.close);

    expect(cubit.state, const StaleMarkersState.idle());
  });

  test('runs, then shows the outcome of the purge', () async {
    final cubit = StaleMarkersCubit(() async => _done);
    addTearDown(cubit.close);
    final states = <StaleMarkersState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);

    await cubit.purge();
    await Future<void>.delayed(Duration.zero);

    expect(states, [
      const StaleMarkersState.running(),
      const StaleMarkersState.finished(_done),
    ]);
  });

  test('a purge in progress is never doubled', () async {
    final gate = Completer<void>();
    var calls = 0;
    final cubit = StaleMarkersCubit(() async {
      calls++;
      await gate.future;
      return _done;
    });
    addTearDown(cubit.close);

    final first = cubit.purge();
    await cubit.purge();
    gate.complete();
    await first;

    expect(calls, 1);
    expect(cubit.state, const StaleMarkersState.finished(_done));
  });

  test('after a stop, the same action runs again', () async {
    var calls = 0;
    final cubit = StaleMarkersCubit(() async {
      calls++;
      return _done;
    });
    addTearDown(cubit.close);

    await cubit.purge();
    await cubit.purge();

    expect(calls, 2);
  });

  test('no state is emitted once the card is closed', () async {
    final gate = Completer<void>();
    final cubit = StaleMarkersCubit(() async {
      await gate.future;
      return _done;
    });

    final running = cubit.purge();
    await cubit.close();
    gate.complete();
    await running;

    expect(cubit.state, const StaleMarkersState.running());
  });
}
