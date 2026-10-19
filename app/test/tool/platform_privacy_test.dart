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

    test('rules: no open access, no expiry date, deny by default', () {
      final rules = File('../firestore.rules')
          .readAsLinesSync()
          .map((line) => line.replaceFirst(RegExp('//.*'), '').trim())
          .join('\n');

      expect(rules, isNot(matches(RegExp(r'if\s+true'))));
      // Les règles complètes (FB3) comparent des dates à `request.time`
      // (création d'une invitation, expiration) mais n'ont jamais de date
      // limite de validité du type « mode test ».
      expect(rules, isNot(contains('timestamp.date')));
      expect(rules, isNot(matches(RegExp(r'request\.time\s*<\s*timestamp'))));
      expect(
        rules,
        matches(RegExp(r'allow\s+read\s*,\s*write\s*:\s*if\s+false')),
      );
    });

    test(
      'rules: e-mail verified, roles by one member read, admin by existence',
      () {
        final rules = File('../firestore.rules').readAsStringSync();

        expect(rules, contains('request.auth.token.email_verified == true'));
        expect(rules, contains(r'/members/$(request.auth.uid)'));
        expect(
          rules,
          contains(r'exists(/databases/$(database)/documents/admins/'),
        );
      },
    );
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
          for (final host in unauthorizedHosts(
            _withoutImportMap(entity.readAsStringSync()),
          )) {
            offenders.add('${entity.path}: $host');
          }
        }
      }

      expect(offenders, isEmpty);
    });

    test('the Firebase web SDK is served locally, never from gstatic.com', () {
      final index = File('web/index.html').readAsStringSync();
      final imports =
          (jsonDecode(
                RegExp(
                  '<script type="importmap">(.*?)</script>',
                  dotAll: true,
                ).firstMatch(index)!.group(1)!,
              ) as Map<String, dynamic>)['imports']
              as Map<String, dynamic>;

      // Seules URL absolues de la page : les clés redirigées vers des fichiers
      // de l'application (ADR 0024, décision 30).
      expect(imports, isNotEmpty);
      for (final entry in imports.entries) {
        expect(entry.key, startsWith('https://www.gstatic.com/firebasejs/'));
        expect(entry.value, startsWith('./firebasejs/'));
        expect(
          File('web/${entry.value}').existsSync(),
          isTrue,
          reason: '${entry.value}',
        );
      }
      expect(unauthorizedHosts(_withoutImportMap(index)), isEmpty);
      expect(unauthorizedHosts(index).toSet(), {'www.gstatic.com'});
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
      !path.endsWith('drift_worker.js') &&
      // Copies épinglées du SDK Firebase (empreintes contrôlées par
      // scripts/sync_firebase_sdk.dart) : leurs commentaires citent des URL.
      !path.contains('web/firebasejs/');
}

/// Texte sans la carte d'import de `index.html` (ses clés sont les URL
/// gstatic.com que la carte redirige vers des fichiers locaux).
String _withoutImportMap(String text) => text.replaceAll(
  RegExp('<script type="importmap">.*?</script>', dotAll: true),
  '',
);
