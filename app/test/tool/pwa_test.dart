import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rejoue `scripts/pwa.dart` dans un faux dépôt (le script déduit la racine de
/// son propre emplacement) : le vrai arbre n'est jamais modifié.
void main() {
  late Directory root;

  File file(String relative) => File('${root.path}/$relative');

  ProcessResult run(List<String> args) =>
      Process.runSync('dart', ['${root.path}/scripts/pwa.dart', ...args]);

  Map<String, dynamic> manifest() =>
      jsonDecode(file('app/web/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

  void writeManifest(Map<String, dynamic> value) =>
      file('app/web/manifest.json').writeAsStringSync(jsonEncode(value));

  void replaceIn(String relative, Pattern from, String to) {
    final target = file(relative);
    target.writeAsStringSync(target.readAsStringSync().replaceAll(from, to));
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('pwa_');
    Directory('${root.path}/scripts').createSync();
    File('../scripts/pwa.dart').copySync('${root.path}/scripts/pwa.dart');
    for (final name in [
      'manifest.json',
      'index.html',
      'offline.js',
      'offline_sw.js',
      'flutter_bootstrap.js',
      'favicon.png',
      'icons/Icon-192.png',
      'icons/Icon-512.png',
      'icons/Icon-maskable-192.png',
      'icons/Icon-maskable-512.png',
    ]) {
      file('app/web/$name').parent.createSync(recursive: true);
      File('web/$name').copySync('${root.path}/app/web/$name');
    }
    Directory('${root.path}/app/lib/app/platform').createSync(recursive: true);
    File(
      'lib/app/platform/app_update_source_web.dart',
    ).copySync('${root.path}/app/lib/app/platform/app_update_source_web.dart');
    Directory('${root.path}/app/lib/shared/ui/theme')
        .createSync(recursive: true);
    File(
      'lib/shared/ui/theme/app_color_schemes.dart',
    ).copySync('${root.path}/app/lib/shared/ui/theme/app_color_schemes.dart');
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('check (sources)', () {
    test('the real web sources are installable and offline-ready', () {
      final result = Process.runSync('dart', ['../scripts/pwa.dart', 'check']);

      expect(result.exitCode, 0, reason: '${result.stderr}');
    });

    test('passes on a consistent copy', () {
      expect(run(['check']).exitCode, 0);
    });

    test('fails when the manifest is not valid JSON', () {
      file('app/web/manifest.json').writeAsStringSync('{ nope');

      final result = run(['check']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('JSON invalide'));
    });

    test('fails when the language is not French', () {
      writeManifest({...manifest(), 'lang': 'en'});

      expect('${run(['check']).stderr}', contains('lang'));
    });

    test('fails when the display is not standalone', () {
      writeManifest({...manifest(), 'display': 'browser'});

      expect('${run(['check']).stderr}', contains('standalone'));
    });

    test('fails on a locked orientation', () {
      writeManifest({...manifest(), 'orientation': 'portrait-primary'});

      final result = run(['check']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('orientation'));
    });

    test('fails when the theme colour differs from the theme primary', () {
      writeManifest({...manifest(), 'theme_color': '#0175C2'});

      expect('${run(['check']).stderr}', contains('theme_color'));
    });

    test('fails when a colour is not #RRGGBB', () {
      writeManifest({...manifest(), 'background_color': 'white'});

      expect('${run(['check']).stderr}', contains('background_color'));
    });

    test('fails without a maskable icon', () {
      final icons = (manifest()['icons'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((i) => i['purpose'] != 'maskable')
          .toList();
      writeManifest({...manifest(), 'icons': icons});

      final result = run(['check']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('maskable:512x512'));
    });

    test('fails when an icon is not the declared size', () {
      final icons = (manifest()['icons'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (i) => i['src'] == 'icons/Icon-192.png'
                ? {...i, 'sizes': '144x144'}
                : i,
          )
          .toList();
      writeManifest({...manifest(), 'icons': icons});

      expect('${run(['check']).stderr}', contains('192x192 réel'));
    });

    test('fails when an icon file is missing', () {
      file('app/web/icons/Icon-512.png').deleteSync();

      expect('${run(['check']).stderr}', contains('Icon-512.png absent'));
    });

    test('fails on an external resource in the page', () {
      replaceIn(
        'app/web/index.html',
        '<title>',
        '<script src="https://cdn.example.com/x.js"></script><title>',
      );

      final result = run(['check']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('index.html : ressource externe'));
    });

    test('fails when the Flutter service worker would be registered', () {
      replaceIn(
        'app/web/flutter_bootstrap.js',
        '_flutter.loader.load();',
        '_flutter.loader.load({serviceWorkerSettings: {}});',
      );

      expect('${run(['check']).stderr}', contains('serviceWorkerSettings'));
    });

    test('fails when the service worker lost its stamp markers', () {
      replaceIn('app/web/offline_sw.js', '/*__PRECACHE__*/ []', '[]');

      expect('${run(['check']).stderr}', contains('marqueurs de stamp'));
    });

    test(
      'fails when the worker would intercept the Firebase /__/ handlers',
      () {
        replaceIn(
          'app/web/offline_sw.js',
          "startsWith('/__/')",
          "startsWith('/zz/')",
        );

        final result = run(['check']);

        expect(result.exitCode, 1);
        expect('${result.stderr}', contains('/__/'));
      },
    );

    test('fails when the page bridge lost a member that Dart reads', () {
      replaceIn('app/web/offline.js', 'applyUpdate:', 'applyUpdateX:');

      final result = run(['check']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('applyUpdate'));
    });

    test('fails when Dart reads a member the page bridge does not expose', () {
      replaceIn(
        'app/lib/app/platform/app_update_source_web.dart',
        'external void applyUpdate();',
        'external void applyUpdate();\n  external void ghost();',
      );

      final result = run(['check']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('ghost'));
    });

    test('the real hosting config verifies the build before every deploy', () {
      final hosting =
          (jsonDecode(File('../firebase.json').readAsStringSync())
                  as Map<String, dynamic>)['hosting']
              as Map<String, dynamic>;

      expect(
        hosting['predeploy'],
        contains('dart run scripts/pwa.dart verify'),
      );
    });

    test('fails when the page is not declared in French', () {
      replaceIn('app/web/index.html', '<html lang="fr">', '<html>');

      expect('${run(['check']).stderr}', contains('lang="fr"'));
    });
  });

  group('stamp and verify (build)', () {
    const required = [
      'index.html',
      'main.dart.js',
      'flutter.js',
      'flutter_bootstrap.js',
      'manifest.json',
      'offline.js',
      'favicon.png',
      'icons/Icon-192.png',
      'icons/Icon-512.png',
      'icons/Icon-maskable-192.png',
      'icons/Icon-maskable-512.png',
      'sqlite3.wasm',
      'drift_worker.js',
      'assets/AssetManifest.bin',
      'assets/FontManifest.json',
      'assets/assets/fonts/Exo2.ttf',
      'assets/assets/catalogue/index.yaml',
      'assets/assets/diagrammes/a.yaml',
      'assets/assets/fiches/s.md',
      'canvaskit/canvaskit.js',
      'canvaskit/canvaskit.wasm',
    ];

    File built(String relative) => file('app/build/web/$relative');

    String workerText() => built('offline_sw.js').readAsStringSync();

    setUp(() {
      for (final name in required) {
        built(name)
          ..createSync(recursive: true)
          ..writeAsStringSync('contenu de $name');
      }
      built('flutter_bootstrap.js').writeAsStringSync(
        'x._flutter.buildConfig = {"useLocalCanvasKit":true};\n'
        '_flutter.loader.load();\n',
      );
      built('index.html').writeAsStringSync('<base href="/">');
      // Fichiers jamais précachés.
      for (final name in [
        'main.dart.js.map',
        'canvaskit/skwasm.wasm',
        'canvaskit/wimp.js',
        'canvaskit/webparagraph/canvaskit.wasm',
        'canvaskit/canvaskit.js.symbols',
        'flutter_service_worker.js',
        '.last_build_id',
      ]) {
        built(name)
          ..createSync(recursive: true)
          ..writeAsStringSync('exclu');
      }
    });

    test('stamp writes the version and the precache list', () {
      final result = run(['stamp']);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final text = workerText();
      expect(text, isNot(contains('__BUILD_ID__')));
      expect(text, contains('"index.html"'));
      expect(text, contains('"canvaskit/canvaskit.wasm"'));
      expect(text, isNot(contains('skwasm')));
      expect(text, isNot(contains('wimp')));
      expect(text, isNot(contains('webparagraph')));
      expect(text, isNot(contains('main.dart.js.map')));
      expect(text, isNot(contains('canvaskit.js.symbols')));
      expect(text, isNot(contains('flutter_service_worker')));
    });

    test('stamp then verify passes', () {
      run(['stamp']);

      final result = run(['verify']);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}', contains('Build web hors ligne OK'));
    });

    test('the version changes with the content and is stable otherwise', () {
      run(['stamp']);
      final first = workerText();
      run(['stamp']);
      expect(workerText(), first);

      built('main.dart.js').writeAsStringSync('nouvelle version');
      run(['stamp']);

      expect(workerText(), isNot(first));
    });

    test('the version changes with the worker itself', () {
      run(['stamp']);
      final first = workerText();

      file('app/web/offline_sw.js').writeAsStringSync(
        '// modifié\n${file('app/web/offline_sw.js').readAsStringSync()}',
      );
      run(['stamp']);

      expect(workerText(), isNot(first));
    });

    test('verify fails on an unstamped build', () {
      built('offline_sw.js')
          .writeAsStringSync(file('app/web/offline_sw.js').readAsStringSync());

      final result = run(['verify']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('non stampé'));
    });

    test('verify fails when a file changed after the stamp', () {
      run(['stamp']);
      built('main.dart.js').writeAsStringSync('modifié après coup');

      final result = run(['verify']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('périmée'));
    });

    test('verify fails when a file was added after the stamp', () {
      run(['stamp']);
      built('nouveau.js').writeAsStringSync('x');

      expect('${run(['verify']).stderr}', contains('liste de précache'));
    });

    test('verify fails when a required file is missing', () {
      built('sqlite3.wasm').deleteSync();
      run(['stamp']);

      final result = run(['verify']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('sqlite3.wasm manquant'));
    });

    test('verify fails when the catalogue assets are missing', () {
      built('assets/assets/catalogue/index.yaml').deleteSync();
      run(['stamp']);

      expect('${run(['verify']).stderr}', contains('assets/assets/catalogue/'));
    });

    test('verify fails when CanvasKit comes from a CDN', () {
      built(
        'flutter_bootstrap.js',
      ).writeAsStringSync('x._flutter.buildConfig = {"engineRevision":"abc"};');
      run(['stamp']);

      final result = run(['verify']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('CDN'));
    });

    test('verify fails when the loader registers the Flutter worker', () {
      built('flutter_bootstrap.js').writeAsStringSync(
        'x._flutter.buildConfig = {"useLocalCanvasKit":true};\n'
        '_flutter.loader.load({serviceWorkerSettings: {}});\n',
      );
      run(['stamp']);

      final result = run(['verify']);

      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('sans réglage'));
    });

    test('verify fails when the base href was not replaced', () {
      built('index.html')
          .writeAsStringSync(r'<base href="$FLUTTER_BASE_HREF">');
      run(['stamp']);

      expect('${run(['verify']).stderr}', contains('FLUTTER_BASE_HREF'));
    });

    test('stamp fails without a build directory', () {
      Directory('${root.path}/app/build').deleteSync(recursive: true);

      expect(run(['stamp']).exitCode, 1);
    });
  });

  test('an unknown command prints the usage', () {
    final result = run(['nope']);

    expect(result.exitCode, 2);
    expect('${result.stderr}', contains('Usage'));
  });
}
