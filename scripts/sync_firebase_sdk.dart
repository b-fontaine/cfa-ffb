// SDK web Firebase servi en local (lot FB5a, ADR 0024 décision 30, B7).
//
//   dart run scripts/sync_firebase_sdk.dart
//       copie (npm pack) vers app/web/firebasejs
//   dart run scripts/sync_firebase_sdk.dart --check
//       vérifie la cohérence (lecture seule, hors ligne)
//
// Pourquoi une « carte d'import » et non un autre mécanisme :
// `firebase_core_web` charge le SDK par `import("https://www.gstatic.com/firebasejs/<version>/…")`,
// l'URL est écrite en dur dans le plugin (seule la version est réglable,
// `window.flutterfire_web_sdk_version`), et les bundles s'importent entre eux
// par cette même URL absolue. Une carte d'import (`<script type="importmap">`
// de `app/web/index.html`) redirige ces URL vers des copies locales,
// **octet pour octet** celles de gstatic, sans fork ni modification du plugin
// (voir docs/engineering/hors-ligne-plan.md).
//
// - la version est celle que le plugin `firebase_core_web` résolu déclare
//   (`supportedFirebaseJsSdkVersion`) : une mise à jour du plugin fait échouer
//   `--check` jusqu'à `dart run scripts/sync_firebase_sdk.dart` ;
// - les fichiers viennent du paquet npm `firebase@<version>` (identique à
//   gstatic, vérifié à l'épinglage) ; `app/web/firebasejs/manifest.json`
//   consigne la version et l'empreinte SHA-256 de chacun.
import 'dart:convert';
import 'dart:io';

/// Racine du dépôt, déduite de l'emplacement du script : le script se rejoue
/// donc dans un faux dépôt pour les tests.
final String _root = File.fromUri(Platform.script).parent.parent.path;

/// Fichiers que le plugin charge (`firebase_auth`, `cloud_firestore`, cœur) ;
/// le bundle Firestore est celui des « pipelines », que le plugin importe.
const _files = <String>[
  'firebase-app.js',
  'firebase-auth.js',
  'firebase-firestore-pipelines.js',
];

const _cdn = 'https://www.gstatic.com/firebasejs';

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  if (args.any((a) => a != '--check')) {
    stderr.writeln('Usage : dart run scripts/sync_firebase_sdk.dart [--check]');
    exit(2);
  }
  final plugin = _pluginSource();
  final version = _declaredVersion(plugin);
  final dir = Directory('$_root/app/web/firebasejs');

  if (!check) _update(dir, version);

  final problems = checkSdk(
    web: Directory('$_root/app/web'),
    pluginSource: plugin,
  );
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    stderr.writeln('Lancer : dart run scripts/sync_firebase_sdk.dart');
    exit(1);
  }
  stdout.writeln(
    'SDK web Firebase $version servi en local : ${_files.length} fichiers '
    'épinglés (SHA-256), carte d’import de index.html cohérente.',
  );
}

/// Anomalies de `app/web` (liste vide = cohérent). Publique pour les tests.
List<String> checkSdk({required Directory web, required String pluginSource}) {
  final problems = <String>[];
  final version = _declaredVersion(pluginSource);
  for (final name in _files) {
    final service = name.replaceFirst('firebase-', '').replaceFirst('.js', '');
    final marker = service == 'firestore-pipelines'
        ? '$_cdn/\$version/firebase-firestore-pipelines.js'
        : '$_cdn/\$version/firebase-\${service.name}.js';
    if (!pluginSource.contains(marker)) {
      problems.add(
        'firebase_core_web ne charge plus « $name » comme prévu '
        '($marker) : revoir scripts/sync_firebase_sdk.dart',
      );
    }
  }

  final manifestFile = File('${web.path}/firebasejs/manifest.json');
  if (!manifestFile.existsSync()) {
    return [...problems, 'app/web/firebasejs/manifest.json absent'];
  }
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map;
  final recorded = manifest['version'];
  if (recorded != version) {
    problems.add(
      'SDK web épinglé en $recorded, firebase_core_web demande $version',
    );
  }
  final hashes = (manifest['sha256'] as Map?)?.cast<String, String>() ?? {};
  if (hashes.keys.toSet().difference(_files.toSet()).isNotEmpty ||
      _files.toSet().difference(hashes.keys.toSet()).isNotEmpty) {
    problems.add('manifest.json : fichiers attendus ${_files.join(', ')}');
  }

  final versionDir = Directory('${web.path}/firebasejs/$recorded');
  final present = versionDir.existsSync()
      ? versionDir.listSync().map((e) => e.uri.pathSegments.last).toSet()
      : <String>{};
  if (!versionDir.existsSync()) {
    problems.add('app/web/firebasejs/$recorded absent');
  }
  for (final name in present.difference(_files.toSet())) {
    problems.add('app/web/firebasejs/$recorded/$name : fichier non prévu');
  }
  final known = _files.toSet();
  for (final name in _files) {
    final file = File('${versionDir.path}/$name');
    if (!file.existsSync()) {
      problems.add('app/web/firebasejs/$recorded/$name absent');
      continue;
    }
    final bytes = file.readAsBytesSync();
    if (sha256Hex(bytes) != hashes[name]) {
      problems.add('$name : empreinte SHA-256 différente de manifest.json');
    }
    // Tout import absolu interne doit être redirigé par la carte.
    for (final m in RegExp(
      '$_cdn/([0-9.]+)/([A-Za-z0-9._-]+)',
    ).allMatches(utf8.decode(bytes, allowMalformed: true))) {
      if (m.group(1) != recorded || !known.contains(m.group(2))) {
        problems.add('$name : import ${m.group(0)} non couvert par la carte');
      }
    }
  }

  final index = File('${web.path}/index.html');
  final text = index.existsSync() ? index.readAsStringSync() : '';
  final map = importMap(text);
  if (map == null) {
    problems.add(
      'index.html : carte d’import (<script type="importmap">) absente',
    );
  } else {
    final expected = {
      for (final name in _files)
        '$_cdn/$recorded/$name': './firebasejs/$recorded/$name',
    };
    if (jsonEncode(
          Map.fromEntries(
            map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
          ),
        ) !=
        jsonEncode(
          Map.fromEntries(
            expected.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
          ),
        )) {
      problems.add(
        'index.html : la carte d’import doit être exactement '
        '${jsonEncode(expected)}',
      );
    }
    final mapAt = text.indexOf('type="importmap"');
    final firstOther = RegExp('<script(?![^>]*importmap)').firstMatch(text);
    if (firstOther != null && firstOther.start < mapAt) {
      problems.add(
        'index.html : la carte d’import doit précéder tout autre script',
      );
    }
  }
  return problems;
}

/// Contenu de la carte d'import de [html] (`imports`), `null` si absente ou
/// invalide. Publique : `scripts/pwa.dart` en a besoin (copie à l'identique).
Map<String, String>? importMap(String html) {
  final match = RegExp(
    r'<script\s+type="importmap"\s*>(.*?)</script>',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) return null;
  try {
    final json = jsonDecode(match.group(1)!);
    final imports = json is Map ? json['imports'] : null;
    if (imports is! Map) return null;
    return {
      for (final entry in imports.entries) '${entry.key}': '${entry.value}',
    };
  } on FormatException {
    return null;
  }
}

void _update(Directory dir, String version) {
  final work = Directory.systemTemp.createTempSync('firebase_sdk_');
  try {
    final pack = Process.runSync('npm', [
      'pack',
      'firebase@$version',
      '--silent',
      '--pack-destination',
      work.path,
    ], workingDirectory: work.path);
    if (pack.exitCode != 0) {
      stderr.writeln('npm pack firebase@$version a échoué : ${pack.stderr}');
      exit(1);
    }
    final archive = '${work.path}/firebase-$version.tgz';
    final untar = Process.runSync('tar', ['-xzf', archive, '-C', work.path]);
    if (untar.exitCode != 0) {
      stderr.writeln('tar a échoué : ${untar.stderr}');
      exit(1);
    }
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final target = Directory('${dir.path}/$version')
      ..createSync(recursive: true);
    final hashes = <String, String>{};
    for (final name in _files) {
      final bytes = File('${work.path}/package/$name').readAsBytesSync();
      File('${target.path}/$name').writeAsBytesSync(bytes);
      hashes[name] = sha256Hex(bytes);
    }
    final manifest = {
      'version': version,
      'source': 'npm firebase@$version, identique à $_cdn/$version/',
      'sha256': hashes,
    };
    File('${dir.path}/manifest.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
  } finally {
    work.deleteSync(recursive: true);
  }
}

String _pluginSource() {
  final config = File('$_root/app/.dart_tool/package_config.json');
  if (!config.existsSync()) {
    stderr.writeln(
      'app/.dart_tool/package_config.json absent : flutter pub get',
    );
    exit(1);
  }
  final json = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  final packages = (json['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final entry = packages.firstWhere((p) => p['name'] == 'firebase_core_web');
  final dir = config.parent.uri
      .resolveUri(Uri.parse(entry['rootUri'] as String))
      .toFilePath();
  return File('$dir/lib/src/firebase_core_web.dart').readAsStringSync() +
      File('$dir/lib/src/firebase_sdk_version.dart').readAsStringSync();
}

String _declaredVersion(String pluginSource) {
  final match = RegExp("supportedFirebaseJsSdkVersion = '([0-9.]+)'")
      .firstMatch(pluginSource);
  if (match == null) {
    stderr.writeln('supportedFirebaseJsSdkVersion introuvable dans le plugin');
    exit(1);
  }
  return match.group(1)!;
}

/// SHA-256 (FIPS 180-4), sans dépendance : le paquet `crypto` n'est pas dans
/// les scripts. Vérifié contre les vecteurs connus dans les tests.
String sha256Hex(List<int> message) {
  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  const mask = 0xffffffff;
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & mask;

  final length = message.length;
  final padded = [...message, 0x80];
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  final bits = length * 8;
  for (var i = 7; i >= 0; i--) {
    padded.add((bits >> (8 * i)) & 0xff);
  }

  final h = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  final w = List<int>.filled(64, 0);
  for (var chunk = 0; chunk < padded.length; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      final j = chunk + i * 4;
      w[i] =
          (padded[j] << 24) |
          (padded[j + 1] << 16) |
          (padded[j + 2] << 8) |
          padded[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & mask;
    }
    var [a, b, c, d, e, f, g, hh] = h;
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & mask) & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & mask;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & mask;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & mask;
    }
    h[0] = (h[0] + a) & mask;
    h[1] = (h[1] + b) & mask;
    h[2] = (h[2] + c) & mask;
    h[3] = (h[3] + d) & mask;
    h[4] = (h[4] + e) & mask;
    h[5] = (h[5] + f) & mask;
    h[6] = (h[6] + g) & mask;
    h[7] = (h[7] + hh) & mask;
  }
  return h.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}
