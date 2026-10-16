import 'dart:async';

import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Le plein écran de la plate-forme hors navigateur.
FullscreenController createPlatformFullscreenController() =>
    NativeFullscreenController();

/// Plein écran mobile : mode immersif (barres système masquées) sur Android
/// et iOS. Le bureau natif n'est pas pris en charge (décision U3-1) : l'entrée
/// est alors masquée.
class NativeFullscreenController implements FullscreenController {
  NativeFullscreenController({TargetPlatform? platform, bool? isWeb})
    : _supported =
          !(isWeb ?? kIsWeb) &&
          const {
            TargetPlatform.android,
            TargetPlatform.iOS,
          }.contains(platform ?? defaultTargetPlatform);

  final bool _supported;
  bool _active = false;
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isSupported => _supported;

  @override
  bool get isActive => _active;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<void> enter() =>
      _switch(active: true, mode: SystemUiMode.immersiveSticky);

  @override
  Future<void> exit() => _switch(active: false, mode: SystemUiMode.edgeToEdge);

  Future<void> _switch({
    required bool active,
    required SystemUiMode mode,
  }) async {
    if (!_supported || _active == active) return;
    try {
      await SystemChrome.setEnabledSystemUIMode(mode);
    } on PlatformException {
      // Refusé par le système : l'état réel ne change pas.
      return;
    }
    _active = active;
    _changes.add(active);
  }
}
