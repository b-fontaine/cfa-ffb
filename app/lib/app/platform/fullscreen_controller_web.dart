import 'dart:js_interop';

import 'package:billard_cfa/app/platform/web_fullscreen_controller.dart';
import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';

/// Le plein écran du navigateur (API Fullscreen).
FullscreenController createPlatformFullscreenController() =>
    WebFullscreenController(_BrowserDocument());

@JS('document')
external _Document get _document;

extension type _Document._(JSObject _) implements JSObject {
  external bool? get fullscreenEnabled;
  external JSObject? get fullscreenElement;
  external _Element get documentElement;
  external JSPromise<JSAny?> exitFullscreen();
  external void addEventListener(String type, JSFunction listener);
}

extension type _Element._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestFullscreen();
}

class _BrowserDocument implements FullscreenDocument {
  @override
  bool get enabled => _document.fullscreenEnabled ?? false;

  @override
  bool get fullscreen => _document.fullscreenElement != null;

  @override
  Future<void> request() =>
      _absorb(_document.documentElement.requestFullscreen());

  @override
  Future<void> exit() => _absorb(_document.exitFullscreen());

  @override
  void onChange(void Function() listener) {
    _document.addEventListener(
      'fullscreenchange',
      ((JSAny? _) => listener()).toJS,
    );
  }

  Future<void> _absorb(JSPromise<JSAny?> promise) =>
      promise.toDart.then((_) {}, onError: (Object _) {});
}
