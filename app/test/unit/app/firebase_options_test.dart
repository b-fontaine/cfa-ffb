import 'package:billard_cfa/app/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android and iOS have their own options, on the single project', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = DefaultFirebaseOptions.currentPlatform;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = DefaultFirebaseOptions.currentPlatform;

    expect(android, DefaultFirebaseOptions.android);
    expect(ios, DefaultFirebaseOptions.ios);
    expect(
      {android.projectId, ios.projectId, DefaultFirebaseOptions.web.projectId},
      {'animation-billard'},
    );
  });

  test('desktop platforms are out of scope (ADR 0024, decision 4)', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;

      expect(
        () => DefaultFirebaseOptions.currentPlatform,
        throwsA(isA<UnsupportedError>()),
      );
    }
  });

  test('an unknown platform is refused too', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

    expect(
      () => DefaultFirebaseOptions.currentPlatform,
      throwsA(isA<UnsupportedError>()),
    );
  });
}
