import 'dart:js_interop';

import 'package:billard_cfa/app/platform/no_app_update_source.dart';
import 'package:billard_cfa/app/platform/web_app_update_source.dart';
import 'package:billard_cfa/shared/lib/app_update_source.dart';

/// La mise à jour du navigateur, si `web/offline.js` a été chargé (absent en
/// test ou dans une page sans service worker : aucune mise à jour proposée).
AppUpdateSource createPlatformAppUpdateSource() {
  final offline = _offline;
  return offline == null
      ? const NoAppUpdateSource()
      : WebAppUpdateSource(_BrowserUpdateBridge(offline));
}

@JS('cfaOffline')
external _Offline? get _offline;

extension type _Offline._(JSObject _) implements JSObject {
  external bool get updateAvailable;
  external void onUpdateChange(JSFunction listener);
  external void applyUpdate();
}

class _BrowserUpdateBridge implements UpdateBridge {
  _BrowserUpdateBridge(this._offline);

  final _Offline _offline;

  @override
  bool get updateAvailable => _offline.updateAvailable;

  @override
  void onUpdateChange(void Function({required bool available}) listener) {
    _offline.onUpdateChange(
      ((JSBoolean available) => listener(available: available.toDart)).toJS,
    );
  }

  @override
  void applyUpdate() => _offline.applyUpdate();
}
