import 'package:billard_cfa/app/platform/no_app_update_source.dart';
import 'package:billard_cfa/app/platform/web_app_update_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBridge implements UpdateBridge {
  _FakeBridge({this.updateAvailable = false});

  @override
  bool updateAvailable;
  int applies = 0;
  void Function({required bool available})? _listener;

  @override
  void onUpdateChange(void Function({required bool available}) listener) =>
      _listener = listener;

  @override
  void applyUpdate() => applies++;

  /// Le service worker signale une version (offline.js).
  void serviceWorkerReports({required bool available}) {
    updateAvailable = available;
    _listener?.call(available: available);
  }
}

void main() {
  test('reads the availability from the page', () {
    expect(WebAppUpdateSource(_FakeBridge()).isAvailable, isFalse);
    expect(
      WebAppUpdateSource(_FakeBridge(updateAvailable: true)).isAvailable,
      isTrue,
    );
  });

  test('forwards every change reported by the service worker', () async {
    final bridge = _FakeBridge();
    final source = WebAppUpdateSource(bridge);
    final seen = <bool>[];
    source.changes.listen(seen.add);

    bridge
      ..serviceWorkerReports(available: true)
      ..serviceWorkerReports(available: false);
    await Future<void>.delayed(Duration.zero);

    expect(seen, [true, false]);
    expect(source.isAvailable, isFalse);
  });

  test('apply activates the waiting version through the page', () async {
    final bridge = _FakeBridge(updateAvailable: true);

    await WebAppUpdateSource(bridge).apply();

    expect(bridge.applies, 1);
  });

  group('NoAppUpdateSource', () {
    const source = NoAppUpdateSource();

    test('never proposes an update', () {
      expect(source.isAvailable, isFalse);
    });

    test('never announces a change', () async {
      expect(await source.changes.isEmpty, isTrue);
    });

    test('applying does nothing and completes', () async {
      await expectLater(source.apply(), completes);
    });
  });
}
