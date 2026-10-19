import 'package:billard_cfa/features/sync_status/domain/sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveSyncState', () {
    test('everything sent, network there: up to date', () {
      expect(
        deriveSyncState(pending: 0, online: true, failed: false),
        SyncState.upToDate,
      );
    });

    test('nothing to send but no network: offline', () {
      final state = deriveSyncState(pending: 0, online: false, failed: false);

      expect(state.phase, SyncPhase.offline);
      expect(state.offline, isTrue);
    });

    test('writes waiting for the server: pending, with their count', () {
      final state = deriveSyncState(pending: 3, online: true, failed: false);

      expect(state.phase, SyncPhase.pending);
      expect(state.pending, 3);
      expect(state.offline, isFalse);
    });

    test('pending and offline: pending, said to be offline', () {
      final state = deriveSyncState(pending: 2, online: false, failed: false);

      expect(state.phase, SyncPhase.pending);
      expect(state.offline, isTrue);
    });

    test('a refused send beats everything else', () {
      for (final pending in [0, 2]) {
        for (final online in [true, false]) {
          expect(
            deriveSyncState(
              pending: pending,
              online: online,
              failed: true,
            ).phase,
            SyncPhase.failed,
          );
        }
      }
    });

    test('states compare by value', () {
      const a = SyncState(phase: SyncPhase.pending, pending: 1);

      expect(a, const SyncState(phase: SyncPhase.pending, pending: 1));
      expect(
        a.hashCode,
        const SyncState(phase: SyncPhase.pending, pending: 1).hashCode,
      );
      expect(a, isNot(const SyncState(phase: SyncPhase.pending, pending: 2)));
      expect(a.toString(), contains('pending'));
    });
  });
}
