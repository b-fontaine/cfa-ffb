import 'dart:async';

import 'package:billard_cfa/shared/lib/app_update_source.dart';

/// Ce que [WebAppUpdateSource] demande à la page : une couture fine qui isole
/// les liaisons `dart:js_interop` (`app_update_source_web.dart`), seules à
/// n'être pas testables dans la machine virtuelle Dart. Elle reflète
/// `window.cfaOffline` (`web/offline.js`).
abstract interface class UpdateBridge {
  /// Vrai si une version attend d'être activée.
  bool get updateAvailable;

  /// [listener] est appelé à chaque changement de [updateAvailable].
  void onUpdateChange(void Function({required bool available}) listener);

  /// Active la version en attente puis recharge la page.
  void applyUpdate();
}

/// Mise à jour du web : l'état fait foi sur le service worker, vu par la page.
class WebAppUpdateSource implements AppUpdateSource {
  WebAppUpdateSource(this._bridge) {
    _bridge.onUpdateChange(({required available}) => _changes.add(available));
  }

  final UpdateBridge _bridge;
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isAvailable => _bridge.updateAvailable;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<void> apply() async => _bridge.applyUpdate();
}
