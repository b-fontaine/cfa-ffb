import 'dart:convert';
import 'dart:io';

import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde-fous de confidentialité des données de mineurs (ADR 0024 et 0025).
///
/// Depuis FB1, prénoms et résultats d'élèves quittent l'appareil **vers
/// Firestore, et vers lui seul** : c'est voulu. Ce qui reste interdit, c'est
/// toute autre sortie : sauvegarde automatique vers le cloud personnel de
/// l'utilisateur (le cache local ne doit pas être copié), ressource ou SDK
/// tiers, règles ouvertes, build de production branché sur l'émulateur.
/// Ce qui dépend des lots suivants (App Check, `clearPersistence` à la
/// déconnexion, persistance explicite) s'ajoutera avec eux (FB2, FB5, FB8).

/// Domaines que le code et les pages web de l'application peuvent contacter :
/// ceux de Firebase (ADR 0025), aucun autre.
const _allowedHostSuffixes = [
  'googleapis.com',
  'firebaseapp.com',
  'firebaseio.com',
];

/// Hôtes (hors liste des domaines autorisés) des URL absolues d'un texte.
List<String> unauthorizedHosts(String text) => [
  for (final match in RegExp('https?://([A-Za-z0-9.-]+)').allMatches(text))
    if (!_allowedHostSuffixes.any(
      (suffix) =>
          match.group(1)! == suffix || match.group(1)!.endsWith('.$suffix'),
    ))
      match.group(1)!,
];

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('device backups', () {
    // Le cache Firestore local et le stockage de l'appareil ne doivent pas
    // être copiés vers le cloud personnel de l'utilisateur (ADR 0025).
    test('Android: automatic cloud backup is disabled', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();

      expect(manifest, contains('android:allowBackup="false"'));
    });

    test('iOS: the documents folder is excluded from iCloud backups', () {
      final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(delegate, contains('isExcludedFromBackup = true'));
      expect(delegate, contains('.documentDirectory'));
    });
  });

  group('Firebase project configuration', () {
    test('Auth: e-mail and password only, no anonymous or Google sign-in', () {
      final config = _json('../firebase.json');

      expect((config['auth'] as Map)['providers'], {'emailPassword': true});
    });

    test('Firestore: database in europe-west9', () {
      final firestore = _json('../firebase.json')['firestore'] as Map;

      expect(firestore['location'], 'europe-west9');
      expect(firestore['rules'], 'firestore.rules');
    });

    test('emulators: local only, no UI, one project', () {
      final emulators = _json('../firebase.json')['emulators'] as Map;

      expect(emulators['singleProjectMode'], isTrue);
      expect((emulators['ui'] as Map)['enabled'], isFalse);
      for (final name in ['auth', 'firestore']) {
        expect((emulators[name] as Map)['host'], '127.0.0.1');
      }
    });

    test('rules: no open access and no expiry date', () {
      final rules = File('../firestore.rules')
          .readAsLinesSync()
          .map((line) => line.replaceFirst(RegExp('//.*'), '').trim())
          .join('\n');

      expect(rules, isNot(matches(RegExp(r'if\s+true'))));
      expect(rules, isNot(contains('request.time')));
      expect(
        rules,
        matches(RegExp(r'allow\s+read\s*,\s*write\s*:\s*if\s+false')),
      );
    });
  });

  group('platforms (ADR 0024, decision 4)', () {
    test('Linux is gone; Firebase options cover Android, iOS and web only', () {
      final platforms =
          (((_json('firebase.json')['flutter'] as Map)['platforms']
                      as Map)['dart']
                  as Map)['lib/app/firebase_options.dart']
              as Map;

      expect(Directory('linux').existsSync(), isFalse);
      expect(
        (platforms['configurations'] as Map).keys,
        unorderedEquals(['android', 'ios', 'web']),
      );
    });
  });

  group('third parties', () {
    test('no URL outside the Firebase domains in lib/ or web/', () {
      final offenders = <String>[];
      for (final root in ['lib', 'web']) {
        for (final entity in Directory(root).listSync(recursive: true)) {
          if (entity is! File || !_isSource(entity.path)) continue;
          for (final host in unauthorizedHosts(entity.readAsStringSync())) {
            offenders.add('${entity.path}: $host');
          }
        }
      }

      expect(offenders, isEmpty);
    });

    test('the scan flags any other domain', () {
      expect(
        unauthorizedHosts(
          'a https://www.googleapis.com/x b https://cdn.example.org/y '
          'c https://animation-billard.firebaseapp.com d http://evil-googleapis.com',
        ),
        ['cdn.example.org', 'evil-googleapis.com'],
      );
    });

    test('no analytics, crash or messaging SDK is a dependency', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      for (final sdk in [
        'firebase_analytics',
        'firebase_crashlytics',
        'firebase_performance',
        'firebase_messaging',
        'firebase_storage',
        'google_sign_in',
      ]) {
        expect(pubspec, isNot(contains(sdk)), reason: sdk);
      }
    });
  });

  group('environments', () {
    test('a release build refuses the emulator flag', () {
      expect(
        () => FirebaseEnvironment.resolve(
          emulatorRequested: true,
          releaseMode: true,
          web: false,
          platform: TargetPlatform.android,
          emulatorHost: '',
        ),
        throwsA(isA<FirebaseEnvironmentError>()),
      );
    });

    test('without the flag no build targets the emulator', () {
      for (final releaseMode in [true, false]) {
        expect(
          FirebaseEnvironment.resolve(
            emulatorRequested: false,
            releaseMode: releaseMode,
            web: false,
            platform: TargetPlatform.android,
            emulatorHost: '',
          ).usesEmulator,
          isFalse,
        );
      }
    });
  });
}

/// Fichiers texte lus par le scan (les blobs générés de drift ne comptent pas).
bool _isSource(String path) {
  if (path.contains('/generated/') ||
      path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('.config.dart')) {
    return false;
  }
  return const ['.dart', '.html', '.js', '.json'].any(path.endsWith) &&
      !path.endsWith('drift_worker.js');
}
