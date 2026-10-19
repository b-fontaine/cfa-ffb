import 'package:billard_cfa/app/platform/signal_connectivity_status.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _Signals implements NetworkSignals {
  @override
  bool online = true;
  void Function({required bool online})? _listener;

  @override
  void listen(void Function({required bool online}) listener) =>
      _listener = listener;

  void browserReports({required bool online}) {
    this.online = online;
    _listener?.call(online: online);
  }
}

void main() {
  test('reads the state from the platform and forwards each change', () async {
    final signals = _Signals();
    final status = SignalConnectivityStatus(signals);
    final seen = <bool>[];
    status.changes.listen(seen.add);
    expect(status.online, isTrue);

    signals
      ..browserReports(online: false)
      ..browserReports(online: true);
    await Future<void>.delayed(Duration.zero);

    expect(seen, [false, true]);
    expect(status.online, isTrue);
  });

  test('without any signal the answer is always online', () async {
    const status = AlwaysOnline();

    expect(status.online, isTrue);
    expect(await status.changes.isEmpty, isTrue);
  });

  test('the test double goes offline and back, once per real change', () async {
    final status = InMemoryConnectivityStatus();
    final seen = <bool>[];
    status.changes.listen(seen.add);

    status
      ..setOnline(value: false)
      ..setOnline(value: false)
      ..setOnline(value: true);
    await Future<void>.delayed(Duration.zero);

    expect(seen, [false, true]);
  });
}
