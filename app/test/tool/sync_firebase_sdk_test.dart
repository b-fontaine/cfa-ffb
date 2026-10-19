import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../scripts/sync_firebase_sdk.dart' show sha256Hex;

/// Rejoue `scripts/sync_firebase_sdk.dart --check` dans un faux dépôt (le
/// script déduit la racine de son propre emplacement) : le vrai arbre n'est
/// jamais touché et aucun téléchargement n'a lieu.
void main() {
  late Directory root;

  File file(String relative) => File('${root.path}/$relative');

  ProcessResult check() => Process.runSync('dart', [
    '${root.path}/scripts/sync_firebase_sdk.dart',
    '--check',
  ]);

  void replaceIn(String relative, Pattern from, String to) {
    final target = file(relative);
    target.writeAsStringSync(target.readAsStringSync().replaceAll(from, to));
  }

  void writePlugin(String version, {bool pipelines = true}) {
    const cdn = 'https://www.gstatic.com/firebasejs';
    file('pkg/firebase_core_web/lib/src/firebase_sdk_version.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "const String supportedFirebaseJsSdkVersion = '$version';\n",
      );
    file('pkg/firebase_core_web/lib/src/firebase_core_web.dart')
        .writeAsStringSync(
          [
            if (pipelines) "'$cdn/\$version/firebase-firestore-pipelines.js'",
            "'$cdn/\$version/firebase-\${service.name}.js'",
          ].join('\n'),
        );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('sync_firebase_sdk_');
    Directory('${root.path}/scripts').createSync();
    File('../scripts/sync_firebase_sdk.dart')
        .copySync('${root.path}/scripts/sync_firebase_sdk.dart');
    file('app/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'firebase_core_web',
              'rootUri': '../../pkg/firebase_core_web',
              'packageUri': 'lib/',
            },
          ],
        }),
      );
    writePlugin('12.19.0');
    // Les vrais fichiers épinglés et la vraie page : la copie doit être
    // cohérente, chaque test en casse un point.
    for (final entity in Directory(
      'web/firebasejs',
    ).listSync(recursive: true)) {
      if (entity is File) {
        final relative = entity.path.substring('web/'.length);
        file('app/web/$relative')
          ..createSync(recursive: true)
          ..writeAsBytesSync(entity.readAsBytesSync());
      }
    }
    File('web/index.html').copySync('${root.path}/app/web/index.html');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('the real tree is consistent with the resolved plugin', () {
    final result = Process.runSync('dart', [
      '../scripts/sync_firebase_sdk.dart',
      '--check',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('passes on a consistent copy', () {
    final result = check();

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect('${result.stdout}', contains('12.19.0'));
  });

  test('fails when the plugin now wants another SDK version', () {
    writePlugin('12.20.0');

    final result = check();

    expect(result.exitCode, 1);
    expect(
      '${result.stderr}',
      contains('épinglé en 12.19.0, firebase_core_web demande 12.20.0'),
    );
  });

  test('fails when a pinned file was modified', () {
    final target = file('app/web/firebasejs/12.19.0/firebase-auth.js');
    target.writeAsStringSync('${target.readAsStringSync()}\n// édité');

    final result = check();

    expect(result.exitCode, 1);
    expect(
      '${result.stderr}',
      contains('firebase-auth.js : empreinte SHA-256 différente'),
    );
  });

  test('fails when a pinned file is missing or unexpected', () {
    file('app/web/firebasejs/12.19.0/firebase-app.js').deleteSync();
    file('app/web/firebasejs/12.19.0/extra.js').writeAsStringSync('x');

    final stderr = '${check().stderr}';

    expect(stderr, contains('firebase-app.js absent'));
    expect(stderr, contains('extra.js : fichier non prévu'));
  });

  test('fails when the import map is missing', () {
    replaceIn(
      'app/web/index.html',
      RegExp('<script type="importmap">.*?</script>', dotAll: true),
      '',
    );

    expect('${check().stderr}', contains('carte d’import'));
  });

  test('fails when the import map misses a file or points elsewhere', () {
    replaceIn(
      'app/web/index.html',
      './firebasejs/12.19.0/firebase-auth.js',
      './firebasejs/12.19.0/firebase-app.js',
    );

    expect('${check().stderr}', contains('doit être exactement'));
  });

  test('fails when another script comes before the import map', () {
    replaceIn(
      'app/web/index.html',
      '<script type="importmap">',
      '<script src="a.js"></script><script type="importmap">',
    );

    expect('${check().stderr}', contains('doit précéder tout autre script'));
  });

  test('fails when a bundle imports a file the map does not cover', () {
    final target = file('app/web/firebasejs/12.19.0/firebase-app.js');
    target.writeAsStringSync(
      '${target.readAsStringSync()}\n'
      'import "https://www.gstatic.com/firebasejs/12.19.0/firebase-other.js";',
    );
    // L'empreinte est recalculée : seul l'import non couvert reste en cause.
    final manifest = file('app/web/firebasejs/manifest.json');
    final json =
        jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    (json['sha256'] as Map<String, dynamic>)['firebase-app.js'] = sha256Hex(
      target.readAsBytesSync(),
    );
    manifest.writeAsStringSync(jsonEncode(json));

    final stderr = '${check().stderr}';

    expect(stderr, contains('firebase-other.js non couvert par la carte'));
    expect(stderr, isNot(contains('empreinte')));
  });

  test('fails when the plugin no longer loads Firestore as expected', () {
    writePlugin('12.19.0', pipelines: false);

    expect(
      '${check().stderr}',
      contains('ne charge plus « firebase-firestore-pipelines.js »'),
    );
  });

  test('sha256 matches the standard test vectors', () {
    expect(
      sha256Hex(<int>[]),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      sha256Hex(
        utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      ),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
    expect(
      sha256Hex(List<int>.filled(1000000, 0x61)),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    );
  });
}
