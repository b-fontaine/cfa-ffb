import 'dart:async';

import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';

/// Ce que [WebFullscreenController] demande au document : une couture fine
/// qui isole les liaisons `dart:js_interop`
/// (`fullscreen_controller_web.dart`), seules à n'être pas testables dans la
/// machine virtuelle Dart.
abstract interface class FullscreenDocument {
  /// Vrai si le navigateur permet le plein écran (faux sur iPhone Safari).
  bool get enabled;

  /// Vrai si un élément est en plein écran.
  bool get fullscreen;

  /// Demande le plein écran. L'appel au navigateur est fait de façon
  /// synchrone (geste de l'utilisateur) ; un refus est absorbé.
  Future<void> request();

  /// Quitte le plein écran ; un refus est absorbé.
  Future<void> exit();

  /// [listener] est appelé à chaque bascule (y compris Échap).
  void onChange(void Function() listener);
}

/// Plein écran du web : l'état fait foi sur le document, pas sur l'appel
/// (le navigateur peut refuser, ou quitter de lui-même avec Échap).
class WebFullscreenController implements FullscreenController {
  WebFullscreenController(this._document) {
    _document.onChange(() => _changes.add(_document.fullscreen));
  }

  final FullscreenDocument _document;
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isSupported => _document.enabled;

  @override
  bool get isActive => _document.fullscreen;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<void> enter() {
    if (!isSupported || isActive) return Future<void>.value();
    return _document.request();
  }

  @override
  Future<void> exit() {
    if (!isActive) return Future<void>.value();
    return _document.exit();
  }
}
