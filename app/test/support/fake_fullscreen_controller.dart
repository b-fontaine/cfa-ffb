import 'dart:async';

import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';

/// Double du plein écran : compte les appels et suit l'état comme le ferait
/// la plate-forme ([emit] simule une bascule venue du navigateur).
class FakeFullscreenController implements FullscreenController {
  FakeFullscreenController({this.supported = true, this.active = false});

  final bool supported;

  /// L'état courant, comme le rapporterait la plate-forme.
  bool active;
  int enterCalls = 0;
  int exitCalls = 0;
  final _changes = StreamController<bool>.broadcast(sync: true);

  @override
  bool get isSupported => supported;

  @override
  bool get isActive => active;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<void> enter() async {
    enterCalls++;
    emit(active: true);
  }

  @override
  Future<void> exit() async {
    exitCalls++;
    emit(active: false);
  }

  /// Une bascule signalée par la plate-forme.
  void emit({required bool active}) {
    this.active = active;
    _changes.add(active);
  }

  Future<void> close() => _changes.close();
}
