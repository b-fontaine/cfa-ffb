// Garde-fous de la version web installable et hors ligne (lot 15).
//
//   dart run scripts/pwa.dart check          sources (app/web) : manifeste, index.html,
//                                            icônes, service worker, aucune
//                                            ressource externe
//   dart run scripts/pwa.dart stamp [dossier] écrit la version et la liste de précache dans
//                                            offline_sw.js du build (défaut app/build/web)
//   dart run scripts/pwa.dart verify [dossier] vérifie le build (défaut app/build/web)
//
// `check` est branché sur scripts/check.sh ; `stamp` et `verify` sur
// scripts/build_web.sh (donc sur la CI et le déploiement). Voir
// docs/engineering/hors-ligne-plan.md.
import 'dart:convert';
import 'dart:io';

/// Racine du dépôt, déduite de l'emplacement du script (comme les autres
/// scripts) : le script se rejoue donc dans un faux dépôt pour les tests.
final String _root = File.fromUri(Platform.script).parent.parent.path;

const _buildIdMarker = "const BUILD_ID = '__BUILD_ID__';";
const _precacheMarker = '/*__PRECACHE__*/ []';

/// Fichiers du build qui ne sont pas précachés : le service worker lui-même,
/// celui (obsolète) de Flutter, les cartes de débogage, et les moteurs inutiles
/// (WebAssembly : le build est en JavaScript ; variante `webparagraph` : non
/// activée). Le service worker garde en cache, après un premier chargement,
/// tout fichier non précaché qui serait finalement demandé.
bool _precached(String path) {
  if (path == 'offline_sw.js' ||
      path == 'flutter_service_worker.js' ||
      path == '.last_build_id') {
    return false;
  }
  if (path.endsWith('.map') || path.endsWith('.symbols')) return false;
  if (path.startsWith('canvaskit/')) {
    final name = path.split('/').last;
    if (name.startsWith('skwasm') || name.startsWith('wimp')) return false;
    // Variante réservée à `preferWebParagraph`, que l'application n'active pas.
    if (path.startsWith('canvaskit/webparagraph/')) return false;
  }
  return true;
}

/// Fichiers sans lesquels l'application ne démarre pas hors ligne.
const _required = <String>[
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
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
];

/// Préfixes d'assets qui doivent être présents au moins une fois (catalogue,
/// diagrammes, fiches de séance : lus à la demande par l'application).
const _requiredPrefixes = <String>[
  'assets/assets/catalogue/',
  'assets/assets/diagrammes/',
  'assets/assets/fiches/',
];

void main(List<String> args) {
  if (args.isEmpty) _usage();
  final problems = switch (args.first) {
    'check' => checkSources(Directory('$_root/app/web')),
    'stamp' => _stamp(_buildDir(args)),
    'verify' => verifyBuild(_buildDir(args)),
    _ => _usage(),
  };
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    exit(1);
  }
}

Never _usage() {
  stderr.writeln(
    'Usage : dart run scripts/pwa.dart check|stamp|verify [dossier]',
  );
  exit(2);
}

Directory _buildDir(List<String> args) =>
    Directory(args.length > 1 ? args[1] : '$_root/app/build/web');

// ---------------------------------------------------------------- sources

/// Contrôle les sources de `app/web`. Retourne les problèmes (vide = OK).
List<String> checkSources(Directory web) {
  final problems = <String>[];
  String? read(String name) {
    final file = File('${web.path}/$name');
    if (!file.existsSync()) {
      problems.add('app/web/$name absent');
      return null;
    }
    return file.readAsStringSync();
  }

  final manifestText = read('manifest.json');
  final index = read('index.html');
  final offline = read('offline.js');
  final worker = read('offline_sw.js');
  final bootstrap = read('flutter_bootstrap.js');

  if (manifestText != null) _checkManifest(web, manifestText, problems);

  if (index != null) {
    if (!RegExp(r'<html[^>]*\blang="fr"').hasMatch(index)) {
      problems.add('index.html : <html lang="fr"> attendu');
    }
    for (final needle in [
      'rel="manifest"',
      'rel="apple-touch-icon"',
      'name="viewport"',
      'name="theme-color"',
      'src="offline.js"',
      r'<base href="$FLUTTER_BASE_HREF">',
    ]) {
      if (!index.contains(needle)) problems.add('index.html : $needle absent');
    }
  }
  if (bootstrap != null) {
    if (!bootstrap.contains('{{flutter_js}}') ||
        !bootstrap.contains('{{flutter_build_config}}')) {
      problems.add(
        'flutter_bootstrap.js : jetons {{flutter_js}} / {{flutter_build_config}} absents',
      );
    }
    if (bootstrap.contains('serviceWorkerSettings')) {
      problems.add(
        'flutter_bootstrap.js : serviceWorkerSettings remplacerait notre '
        'service worker par celui de Flutter',
      );
    }
  }
  if (worker != null) {
    if (!worker.contains(_buildIdMarker) || !worker.contains(_precacheMarker)) {
      problems.add('offline_sw.js : marqueurs de stamp absents');
    }
    if (!worker.contains("startsWith('/__/')")) {
      problems.add(
        'offline_sw.js : les gestionnaires Firebase /__/ ne doivent pas être '
        "interceptés (startsWith('/__/') absent)",
      );
    }
    if (!worker.contains('skipWaiting') || !worker.contains('SKIP_WAITING')) {
      problems.add(
        'offline_sw.js : activation à la demande (SKIP_WAITING) absente',
      );
    }
  }
  if (offline != null && !offline.contains("register('offline_sw.js'")) {
    problems.add('offline.js : enregistrement de offline_sw.js absent');
  }

  if (offline != null) _checkBridge(web, offline, problems);

  // Aucune ressource externe à l'exécution : ni dans la page, ni dans les
  // scripts de démarrage, ni dans le service worker.
  final external = RegExp(
    r'''(?:src|href)\s*=\s*["']https?://|['"]https?://''',
  );
  // La seule URL absolue de la page : les clés de la carte d'import du SDK
  // Firebase (redirigées vers des copies locales, voir
  // scripts/sync_firebase_sdk.dart). Elle est contrôlée à part puis retirée du
  // texte examiné.
  var indexWithoutMap = index;
  if (index != null) {
    final mapBlock = RegExp(
      r'<script\s+type="importmap"\s*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(index);
    if (mapBlock == null) {
      problems.add(
        'index.html : carte d’import du SDK Firebase absente '
        '(le SDK serait chargé depuis gstatic.com)',
      );
    } else {
      indexWithoutMap = index.replaceFirst(mapBlock.group(0)!, '');
      _checkImportMap(mapBlock.group(1)!, problems);
    }
  }
  for (final entry in {
    'index.html': indexWithoutMap,
    'offline.js': offline,
    'offline_sw.js': worker,
    'flutter_bootstrap.js': bootstrap,
  }.entries) {
    final text = entry.value;
    if (text != null && external.hasMatch(text)) {
      problems.add('${entry.key} : ressource externe (CDN) interdite');
    }
  }
  return problems;
}

/// La carte d'import ne redirige que le SDK Firebase de gstatic.com, et
/// uniquement vers des fichiers locaux.
void _checkImportMap(String json, List<String> problems) {
  Object? imports;
  try {
    final decoded = jsonDecode(json);
    imports = decoded is Map ? decoded['imports'] : null;
  } on FormatException {
    imports = null;
  }
  if (imports is! Map) {
    problems.add('index.html : carte d’import illisible (JSON invalide)');
    return;
  }
  for (final entry in imports.entries) {
    final key = '${entry.key}';
    final value = '${entry.value}';
    if (!key.startsWith('https://www.gstatic.com/firebasejs/')) {
      problems.add(
        'index.html : la carte d’import ne peut viser que le SDK Firebase '
        '($key)',
      );
    }
    if (!value.startsWith('./firebasejs/')) {
      problems.add(
        'index.html : la carte d’import doit rediriger vers ./firebasejs/ '
        '($key vers $value)',
      );
    }
  }
}

/// Contrat entre le pont JavaScript (`offline.js`) et sa liaison Dart
/// (`app_update_source_web.dart`) : chaque membre lu côté Dart doit exister
/// côté JavaScript, et inversement (le pont n'est testé que séparément, de
/// chaque côté).
void _checkBridge(Directory web, String offline, List<String> problems) {
  const members = ['updateAvailable', 'onUpdateChange', 'applyUpdate'];
  for (final member in members) {
    // Clé d'objet ou accesseur (hors commentaires : précédé d'un point).
    if (!RegExp('(?:^|\\s)(?:get\\s+)?$member\\s*[:(]').hasMatch(offline)) {
      problems.add('offline.js : membre « $member » du pont absent');
    }
  }
  final dart = File(
    '${web.parent.path}/lib/app/platform/app_update_source_web.dart',
  );
  if (!dart.existsSync()) return;
  final declared = RegExp(r'external\s+[\w<>?]+\s+(?:get\s+)?(\w+)')
      .allMatches(_extensionBody(dart.readAsStringSync()))
      .map((m) => m.group(1)!);
  for (final member in declared) {
    if (!members.contains(member)) {
      problems.add(
        'app_update_source_web.dart : « $member » lu côté Dart mais absent du '
        'pont offline.js',
      );
    }
  }
}

/// Corps de l'`extension type _Offline` (les membres JS lus côté Dart).
String _extensionBody(String dart) {
  final start = dart.indexOf('extension type _Offline');
  if (start < 0) return '';
  final open = dart.indexOf('{', start);
  final close = dart.indexOf('\n}', open);
  return open < 0 || close < 0 ? '' : dart.substring(open, close);
}

void _checkManifest(Directory web, String text, List<String> problems) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    problems.add('manifest.json : JSON invalide (${e.message})');
    return;
  }
  if (decoded is! Map<String, dynamic>) {
    problems.add('manifest.json : objet attendu');
    return;
  }
  final m = decoded;
  for (final key in [
    'name',
    'short_name',
    'description',
    'start_url',
    'scope',
    'id',
  ]) {
    if (m[key] is! String || (m[key] as String).isEmpty) {
      problems.add('manifest.json : « $key » manquant');
    }
  }
  if (m['lang'] != 'fr') problems.add('manifest.json : lang « fr » attendu');
  if (m['display'] != 'standalone') {
    problems.add('manifest.json : display « standalone » attendu');
  }
  final orientation = m['orientation'];
  if (orientation is String && orientation != 'any') {
    problems.add(
      'manifest.json : orientation libre (« any ») attendue, '
      'pas « $orientation » '
      '(le plein écran impose de pouvoir pivoter)',
    );
  }
  final hex = RegExp(r'^#[0-9A-Fa-f]{6}$');
  for (final key in ['theme_color', 'background_color']) {
    final value = m[key];
    if (value is! String || !hex.hasMatch(value)) {
      problems.add('manifest.json : « $key » doit être une couleur #RRGGBB');
    }
  }
  _checkThemeColor(web, m['theme_color'], problems);

  final icons = m['icons'];
  if (icons is! List) {
    problems.add('manifest.json : « icons » manquant');
    return;
  }
  final found = <String>{};
  for (final raw in icons) {
    if (raw is! Map<String, dynamic>) continue;
    final src = raw['src'] as String?;
    final sizes = raw['sizes'] as String?;
    final purpose = (raw['purpose'] as String?) ?? 'any';
    if (src == null || sizes == null) {
      problems.add('manifest.json : icône sans src ou sizes');
      continue;
    }
    if (raw['type'] != 'image/png') {
      problems.add('manifest.json : $src doit déclarer type image/png');
    }
    final file = File('${web.path}/$src');
    if (!file.existsSync()) {
      problems.add('manifest.json : $src absent de app/web');
      continue;
    }
    final size = _pngSize(file);
    if (size == null) {
      problems.add('$src : PNG illisible');
    } else if ('${size.$1}x${size.$2}' != sizes) {
      problems.add('$src : ${size.$1}x${size.$2} réel, « $sizes » déclaré');
    }
    found.add('$purpose:$sizes');
  }
  for (final need in [
    'any:192x192',
    'any:512x512',
    'maskable:192x192',
    'maskable:512x512',
  ]) {
    if (!found.contains(need)) {
      problems.add('manifest.json : icône « $need » manquante');
    }
  }
}

/// La couleur de thème du manifeste est le `primary` du thème clair.
void _checkThemeColor(Directory web, Object? declared, List<String> problems) {
  final schemes = File(
    '${web.parent.path}/lib/shared/ui/theme/app_color_schemes.dart',
  );
  if (declared is! String || !schemes.existsSync()) return;
  final match = RegExp(r'primary:\s*Color\(0xFF([0-9A-Fa-f]{6})\)')
      .firstMatch(schemes.readAsStringSync());
  if (match != null &&
      match.group(1)!.toLowerCase() != declared.substring(1).toLowerCase()) {
    problems.add(
      'manifest.json : theme_color $declared ≠ primary du thème '
      '(#${match.group(1)})',
    );
  }
}

(int, int)? _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  int u32(int at) =>
      (bytes[at] << 24) |
      (bytes[at + 1] << 16) |
      (bytes[at + 2] << 8) |
      bytes[at + 3];
  return (u32(16), u32(20));
}

// ------------------------------------------------------------------ build

/// Fichiers précachés du build (chemins relatifs, séparateur `/`, triés).
List<String> precacheList(Directory build) {
  final base = build.path.endsWith('/') ? build.path : '${build.path}/';
  final paths = <String>[
    for (final entity in build.listSync(recursive: true))
      if (entity is File)
        entity.path.replaceAll(r'\', '/').substring(base.length),
  ]..removeWhere((p) => !_precached(p));
  return paths..sort();
}

/// Empreinte (FNV-1a 64 bits : détection de changement, pas de sécurité) du
/// contenu précaché et du service worker modèle.
String buildId(Directory build, List<String> paths, String workerTemplate) {
  var hash = 0xcbf29ce484222325;
  void feed(List<int> bytes) {
    for (final b in bytes) {
      hash = (hash ^ b) * 0x100000001b3;
    }
  }

  feed(utf8.encode(workerTemplate));
  for (final path in paths) {
    feed(utf8.encode('\u0000$path\u0000'));
    feed(File('${build.path}/$path').readAsBytesSync());
  }
  // Les entiers Dart sont signés sur 64 bits : écrire les deux moitiés.
  String half(int value) =>
      (value & 0xffffffff).toRadixString(16).padLeft(8, '0');
  return half(hash >>> 32) + half(hash);
}

List<String> _stamp(Directory build) {
  final template = File('$_root/app/web/offline_sw.js');
  if (!build.existsSync() || !template.existsSync()) {
    return ['build ou modèle de service worker introuvable : ${build.path}'];
  }
  final source = template.readAsStringSync();
  if (!source.contains(_buildIdMarker) || !source.contains(_precacheMarker)) {
    return ['offline_sw.js : marqueurs de stamp absents'];
  }
  final paths = precacheList(build);
  final id = buildId(build, paths, source);
  File('${build.path}/offline_sw.js').writeAsStringSync(
    source
        .replaceFirst(_buildIdMarker, "const BUILD_ID = '$id';")
        .replaceFirst(_precacheMarker, jsonEncode(paths)),
  );
  stdout.writeln(
    'Service worker hors ligne : version $id, '
    '${paths.length} fichiers précachés.',
  );
  return const [];
}

/// Contrôle un build stampé. Retourne les problèmes (vide = OK).
List<String> verifyBuild(Directory build) {
  final problems = <String>[];
  final workerFile = File('${build.path}/offline_sw.js');
  final template = File('$_root/app/web/offline_sw.js');
  if (!workerFile.existsSync()) {
    return ['offline_sw.js absent du build : lancer scripts/build_web.sh'];
  }
  final worker = workerFile.readAsStringSync();
  final idMatch = RegExp("const BUILD_ID = '([0-9a-f]{16})';")
      .firstMatch(worker);
  final listMatch = RegExp(
    r'const PRECACHE = (\[.*?\]);',
    dotAll: true,
  ).firstMatch(worker);
  if (idMatch == null || listMatch == null) {
    return ['offline_sw.js non stampé : lancer scripts/build_web.sh'];
  }
  final listed = (jsonDecode(listMatch.group(1)!) as List<dynamic>)
      .cast<String>();
  final actual = precacheList(build);
  if (listed.join('\n') != actual.join('\n')) {
    problems.add(
      'offline_sw.js : liste de précache différente du contenu du build',
    );
  } else if (template.existsSync() &&
      buildId(build, actual, template.readAsStringSync()) != idMatch.group(1)) {
    problems.add(
      'offline_sw.js : version périmée (fichiers modifiés après le stamp)',
    );
  }
  for (final path in _required) {
    if (!listed.contains(path)) problems.add('précache : $path manquant');
  }
  _requireFirebaseSdk(build, listed, problems);
  for (final prefix in _requiredPrefixes) {
    if (!listed.any((p) => p.startsWith(prefix))) {
      problems.add('précache : aucun fichier sous $prefix');
    }
  }
  final bootstrap = File('${build.path}/flutter_bootstrap.js');
  if (bootstrap.existsSync()) {
    final text = bootstrap.readAsStringSync();
    if (!text.contains('"useLocalCanvasKit":true')) {
      problems.add(
        'flutter_bootstrap.js : CanvasKit chargé depuis un CDN '
        '(construire avec --no-web-resources-cdn)',
      );
    }
    // Le chargeur est lancé sans réglage de service worker (le code de la
    // bibliothèque, lui, en mentionne le nom).
    if (!RegExp(r'_flutter\.loader\.load\(\s*\)\s*;\s*$').hasMatch(text)) {
      problems.add(
        'flutter_bootstrap.js : le chargeur doit être lancé sans réglage '
        '(sinon le service worker de Flutter remplace le nôtre)',
      );
    }
  }
  final index = File('${build.path}/index.html');
  if (index.existsSync() &&
      index.readAsStringSync().contains(r'$FLUTTER_BASE_HREF')) {
    problems.add(r'index.html : $FLUTTER_BASE_HREF non remplacé');
  }
  if (problems.isEmpty) {
    stdout.writeln(
      'Build web hors ligne OK : version ${idMatch.group(1)}, '
      '${listed.length} fichiers précachés.',
    );
  }
  return problems;
}

/// Le SDK web Firebase épinglé (app/web/firebasejs) est dans le build et dans
/// le précache : sans lui, la première visite hors ligne n'initialiserait pas
/// Firebase.
void _requireFirebaseSdk(
  Directory build,
  List<String> listed,
  List<String> problems,
) {
  final manifest = File('${build.path}/firebasejs/manifest.json');
  if (!manifest.existsSync()) {
    problems.add(
      'build : firebasejs/manifest.json absent (SDK Firebase local)',
    );
    return;
  }
  final json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
  final version = json['version'];
  final files = ((json['sha256'] as Map<String, dynamic>?) ?? {}).keys;
  if (files.isEmpty) problems.add('firebasejs/manifest.json : aucun fichier');
  for (final name in files) {
    if (!listed.contains('firebasejs/$version/$name')) {
      problems.add('précache : firebasejs/$version/$name manquant');
    }
  }
}
