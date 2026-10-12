@Tags(['tooling'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les prénoms et résultats d'élèves mineurs ne quittent pas l'appareil :
/// aucune sauvegarde automatique vers le cloud de l'utilisateur
/// (docs/engineering/research/firebase.md, ADR 0001).
void main() {
  test('Android: automatic cloud backup of the database is disabled', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('iOS: the documents folder is excluded from iCloud backups', () {
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(delegate, contains('isExcludedFromBackup = true'));
    expect(delegate, contains('.documentDirectory'));
  });
}
