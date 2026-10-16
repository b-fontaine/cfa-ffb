import 'dart:async';

import 'package:billard_cfa/app/platform/web_fullscreen_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDocument implements FullscreenDocument {
  _FakeDocument({this.enabled = true, this.refuseRequest = false});

  @override
  final bool enabled;
  @override
  bool fullscreen = false;
  final bool refuseRequest;
  int requests = 0;
  int exits = 0;
  void Function()? _listener;

  @override
  Future<void> request() async {
    requests++;
    if (refuseRequest) return;
    fullscreen = true;
    _listener?.call();
  }

  @override
  Future<void> exit() async {
    exits++;
    fullscreen = false;
    _listener?.call();
  }

  @override
  void onChange(void Function() listener) => _listener = listener;

  /// Échap dans le navigateur.
  void browserLeaves() {
    fullscreen = false;
    _listener?.call();
  }
}

void main() {
  test('is supported when the document allows the full screen', () {
    expect(WebFullscreenController(_FakeDocument()).isSupported, isTrue);
    expect(
      WebFullscreenController(_FakeDocument(enabled: false)).isSupported,
      isFalse,
    );
  });

  test('asks the document right away, in the user gesture', () {
    final document = _FakeDocument();
    final controller = WebFullscreenController(document);

    // Pas de `await` : l'appel est synchrone.
    unawaited(controller.enter());

    expect(document.requests, 1);
    expect(controller.isActive, isTrue);
  });

  test(
    'follows the document, including a change made by the browser',
    () async {
      final document = _FakeDocument();
      final controller = WebFullscreenController(document);
      final changes = <bool>[];
      controller.changes.listen(changes.add);

      await controller.enter();
      document.browserLeaves();
      await pumpEventQueue();

      expect(changes, [true, false]);
      expect(controller.isActive, isFalse);
    },
  );

  test('leaves only from the full screen', () async {
    final document = _FakeDocument();
    final controller = WebFullscreenController(document);

    await controller.exit();
    expect(document.exits, 0);

    await controller.enter();
    await controller.exit();
    expect(document.exits, 1);
  });

  test('does not enter twice nor where it is not enabled', () async {
    final document = _FakeDocument();
    final controller = WebFullscreenController(document);
    await controller.enter();
    await controller.enter();
    expect(document.requests, 1);

    final blocked = _FakeDocument(enabled: false);
    await WebFullscreenController(blocked).enter();
    expect(blocked.requests, 0);
  });

  test(
    'stays inactive and silent when the browser refuses the request',
    () async {
      final document = _FakeDocument(refuseRequest: true);
      final controller = WebFullscreenController(document);
      final changes = <bool>[];
      controller.changes.listen(changes.add);

      await controller.enter();
      await pumpEventQueue();

      expect(document.requests, 1);
      expect(controller.isActive, isFalse);
      expect(changes, isEmpty);
    },
  );

  test(
    'ignores an exit when the browser already left the full screen',
    () async {
      final document = _FakeDocument();
      final controller = WebFullscreenController(document);
      await controller.enter();
      document.browserLeaves();

      await controller.exit();

      expect(document.exits, 0);
      expect(controller.isActive, isFalse);
    },
  );
}
