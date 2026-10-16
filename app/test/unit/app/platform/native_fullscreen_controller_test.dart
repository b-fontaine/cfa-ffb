import 'package:billard_cfa/app/platform/fullscreen_controller_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> modes;
  late bool refuse;

  setUp(() {
    modes = [];
    refuse = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            if (refuse) throw PlatformException(code: 'refused');
            modes.add(call.arguments as String);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  NativeFullscreenController controller(TargetPlatform platform) =>
      NativeFullscreenController(platform: platform, isWeb: false);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('is supported on $platform', () {
      expect(controller(platform).isSupported, isTrue);
    });
  }

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    test('is not supported on the desktop ($platform)', () {
      expect(controller(platform).isSupported, isFalse);
    });
  }

  test('is not supported in a browser, which has its own controller', () {
    expect(
      NativeFullscreenController(
        platform: TargetPlatform.android,
        isWeb: true,
      ).isSupported,
      isFalse,
    );
  });

  test('enters the immersive mode and reports it', () async {
    final fullscreen = controller(TargetPlatform.android);
    final changes = <bool>[];
    fullscreen.changes.listen(changes.add);

    await fullscreen.enter();
    await pumpEventQueue();

    expect(modes, ['SystemUiMode.immersiveSticky']);
    expect(fullscreen.isActive, isTrue);
    expect(changes, [true]);
  });

  test('goes back to edge-to-edge when leaving', () async {
    final fullscreen = controller(TargetPlatform.iOS);
    await fullscreen.enter();

    await fullscreen.exit();

    expect(modes.last, 'SystemUiMode.edgeToEdge');
    expect(fullscreen.isActive, isFalse);
  });

  test('does not call the system twice for the same state', () async {
    final fullscreen = controller(TargetPlatform.android);

    await fullscreen.exit();
    await fullscreen.enter();
    await fullscreen.enter();

    expect(modes, ['SystemUiMode.immersiveSticky']);
  });

  test('does nothing where it is not supported', () async {
    final fullscreen = controller(TargetPlatform.linux);

    await fullscreen.enter();

    expect(modes, isEmpty);
    expect(fullscreen.isActive, isFalse);
  });

  test('keeps its state when the system refuses', () async {
    refuse = true;
    final fullscreen = controller(TargetPlatform.android);

    await fullscreen.enter();

    expect(fullscreen.isActive, isFalse);
  });

  test('the factory gives the controller of the platform', () {
    expect(
      createPlatformFullscreenController(),
      isA<NativeFullscreenController>(),
    );
  });
}
