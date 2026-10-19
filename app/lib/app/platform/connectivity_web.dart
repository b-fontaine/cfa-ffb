import 'dart:js_interop';

import 'package:billard_cfa/app/platform/signal_connectivity_status.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';

/// L'état du réseau du navigateur (`navigator.onLine`).
ConnectivityStatus createPlatformConnectivityStatus() =>
    SignalConnectivityStatus(_BrowserNetwork());

@JS('navigator')
external _Navigator get _navigator;

@JS('window')
external _Window get _window;

extension type _Navigator._(JSObject _) implements JSObject {
  external bool get onLine;
}

extension type _Window._(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
}

class _BrowserNetwork implements NetworkSignals {
  @override
  bool get online => _navigator.onLine;

  @override
  void listen(void Function({required bool online}) listener) {
    _window
      ..addEventListener('online', ((JSAny? _) => listener(online: true)).toJS)
      ..addEventListener(
        'offline',
        ((JSAny? _) => listener(online: false)).toJS,
      );
  }
}
