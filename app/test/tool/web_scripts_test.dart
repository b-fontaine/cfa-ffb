import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Forme des scripts qui choisissent le backend d'un build web. Leur exécution
/// (Chrome, build complet) n'est pas dans `flutter test` : si le drapeau drift
/// explicite disparaît, seule l'exécution échouerait. Ce test fige où le
/// drapeau est voulu et interdit tout drapeau Firestore redondant (le défaut du
/// build est Firestore, bascule du 2026-10-21).
const _drift = '--dart-define=DATA_BACKEND=drift';

List<String> _lines(String path) {
  final lines = File('../$path').readAsLinesSync();
  // Les commentaires disent le drapeau sans le passer : seules les commandes
  // comptent.
  return [
    for (final line in lines)
      if (!line.trimLeft().startsWith('#')) line,
  ];
}

Iterable<String> _builds(String path) =>
    _lines(path).where((l) => l.contains('scripts/build_web.sh'));

void main() {
  test('web_smoke.sh builds drift, explicitly', () {
    final builds = _builds('scripts/web_smoke.sh').toList();

    expect(builds, hasLength(1));
    expect(builds.single, contains(_drift));
  });

  test('web_smoke.sh never reuses an existing build, whatever its backend', () {
    final commands = _lines('scripts/web_smoke.sh').join('\n');
    final build = _builds('scripts/web_smoke.sh').single;

    // Le build est inconditionnel (en tête de ligne, hors `if`) et le script ne
    // teste plus l'existence de app/build/web, qui peut être un build Firestore.
    expect(build, startsWith('"'));
    expect(commands, isNot(contains('index.html')));
    expect(commands, isNot(contains('--build')));
  });

  test('local_data_web.sh builds firestore bare, then drift explicitly', () {
    final builds = _builds('scripts/local_data_web.sh').toList();

    expect(builds, hasLength(2));
    // Le build Firestore d'abord, sans aucun drapeau de backend ; drift en
    // dernier (c'est celui que app/build/web doit contenir ensuite).
    expect(builds.first, isNot(contains('DATA_BACKEND')));
    expect(builds.last, contains(_drift));
  });

  test('no script passes a redundant Firestore flag', () {
    final scripts = [
      for (final entity in Directory('../scripts').listSync(recursive: true))
        if (entity is File &&
            (entity.path.endsWith('.sh') || entity.path.endsWith('.mjs')) &&
            !entity.path.contains('node_modules'))
          entity.path,
    ];

    expect(scripts, isNotEmpty);
    for (final path in scripts) {
      final commands = [
        for (final line in File(path).readAsLinesSync())
          if (!line.trimLeft().startsWith('#') &&
              !line.trimLeft().startsWith('//'))
            line,
      ].join('\n');
      expect(commands, isNot(contains('DATA_BACKEND=firestore')), reason: path);
    }
  });
}
