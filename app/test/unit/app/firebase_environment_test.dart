import 'dart:convert';
import 'dart:io';

import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FirebaseEnvironment resolve({
    bool emulatorRequested = false,
    bool releaseMode = false,
    bool web = false,
    TargetPlatform platform = TargetPlatform.android,
    String emulatorHost = '',
  }) => FirebaseEnvironment.resolve(
    emulatorRequested: emulatorRequested,
    releaseMode: releaseMode,
    web: web,
    platform: platform,
    emulatorHost: emulatorHost,
  );

  group('safe default', () {
    test('debug without the flag targets production, never the emulator', () {
      final environment = resolve();

      expect(environment.target, FirebaseTarget.production);
      expect(environment.usesEmulator, isFalse);
      expect(environment.emulatorHost, isNull);
    });

    test('release without the flag targets production', () {
      final environment = resolve(releaseMode: true);

      expect(environment.target, FirebaseTarget.production);
      expect(environment.usesEmulator, isFalse);
    });

    test('an unset host with no flag stays on production', () {
      expect(
        resolve(emulatorHost: '192.168.1.20').target,
        FirebaseTarget.production,
      );
    });
  });

  group('emulator', () {
    test('debug with the flag targets the emulator', () {
      final environment = resolve(emulatorRequested: true);

      expect(environment.target, FirebaseTarget.emulator);
      expect(environment.usesEmulator, isTrue);
    });

    test('the Android emulator reaches the host machine at 10.0.2.2', () {
      expect(resolve(emulatorRequested: true).emulatorHost, '10.0.2.2');
    });

    test('iOS, desktop and web use the loopback address', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        expect(
          resolve(emulatorRequested: true, platform: platform).emulatorHost,
          '127.0.0.1',
        );
      }
      expect(
        resolve(emulatorRequested: true, web: true).emulatorHost,
        '127.0.0.1',
      );
    });

    test('web wins over the Android default host', () {
      // Chrome sur Android rapporte `TargetPlatform.android` avec kIsWeb.
      expect(
        resolve(emulatorRequested: true, web: true).emulatorHost,
        '127.0.0.1',
      );
    });

    test('a host can be given for a physical device', () {
      expect(
        resolve(
          emulatorRequested: true,
          emulatorHost: '192.168.1.20',
        ).emulatorHost,
        '192.168.1.20',
      );
    });
  });

  group('release', () {
    test('refuses the emulator, loudly', () {
      expect(
        () => resolve(emulatorRequested: true, releaseMode: true),
        throwsA(isA<FirebaseEnvironmentError>()),
      );
    });

    test('the refusal explains how to fix the build', () {
      expect(
        () => resolve(emulatorRequested: true, releaseMode: true),
        throwsA(
          isA<FirebaseEnvironmentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('FIREBASE_EMULATOR'), contains('release')),
          ),
        ),
      );
    });
  });

  group('ports', () {
    test('match the emulators declared in firebase.json', () {
      final config = jsonDecode(
        File('../firebase.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final emulators = config['emulators'] as Map<String, dynamic>;

      expect(
        (emulators['auth'] as Map<String, dynamic>)['port'],
        FirebaseEnvironment.authPort,
      );
      expect(
        (emulators['firestore'] as Map<String, dynamic>)['port'],
        FirebaseEnvironment.firestorePort,
      );
    });
  });

  group('emulator project', () {
    test('is the project the emulators and the seed are launched on', () {
      const id = FirebaseEnvironment.emulatorProjectId;

      expect(id, startsWith('demo-'));
      expect(
        File('../Taskfile.yml').readAsStringSync(),
        contains('--project $id'),
      );
      expect(
        File('../scripts/rules_test.sh').readAsStringSync(),
        contains('RULES_TEST_PROJECT:-$id'),
      );
      expect(File('../scripts/web_smoke.sh').readAsStringSync(), contains(id));
    });
  });

  group('build flags', () {
    test('without --dart-define the build targets production', () {
      // Les tests tournent en debug, sans FIREBASE_EMULATOR.
      final environment = FirebaseEnvironment.fromBuild();

      expect(environment.target, FirebaseTarget.production);
    });
  });
}
