// Fichiers web de la persistance drift (sqlite3.wasm + drift_worker.js).
//
//   dart run scripts/sync_web_assets.dart          copie / télécharge vers app/web
//   dart run scripts/sync_web_assets.dart --check  vérifie la cohérence (lecture seule)
//
// - `drift_worker.js` doit être celui du paquet `drift` résolu (même version) :
//   copié depuis le cache pub, comparé octet à octet.
// - `sqlite3.wasm` doit correspondre à la version du paquet `sqlite3`
//   verrouillée
//   dans app/pubspec.lock : téléchargé depuis la release GitHub
//   `sqlite3-<version>` de simolus3/sqlite3.dart ; `app/web/sqlite3.wasm.version`
//   consigne la version copiée.
import 'dart:convert';
import 'dart:io';

const _wasmMagic = [0x00, 0x61, 0x73, 0x6d];

/// Racine du dépôt, déduite de l'emplacement du script (comme les scripts
/// shell) : le script se rejoue donc dans un faux dépôt pour les tests.
final String _root = File.fromUri(Platform.script).parent.parent.path;

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  if (args.any((a) => a != '--check')) {
    stderr.writeln('Usage : dart run scripts/sync_web_assets.dart [--check]');
    exit(2);
  }
  final web = Directory('$_root/app/web');
  final sqliteVersion = _lockedVersion('sqlite3');
  final workerSource = File('${_packageDir('drift')}/drift_worker.js');
  final worker = File('${web.path}/drift_worker.js');
  final wasm = File('${web.path}/sqlite3.wasm');
  final versionFile = File('${web.path}/sqlite3.wasm.version');

  if (!check) {
    worker.writeAsBytesSync(workerSource.readAsBytesSync());
    final url = Uri.parse(
      'https://github.com/simolus3/sqlite3.dart/releases/download/'
      'sqlite3-$sqliteVersion/sqlite3.wasm',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) {
        stderr.writeln(
          'Téléchargement impossible ($url) : ${response.statusCode}',
        );
        exit(1);
      }
      final bytes = await response.fold<List<int>>(
        [],
        (all, c) => all..addAll(c),
      );
      wasm.writeAsBytesSync(bytes);
      versionFile.writeAsStringSync('$sqliteVersion\n');
    } finally {
      client.close();
    }
  }

  final problems = <String>[];
  if (!worker.existsSync()) {
    problems.add('app/web/drift_worker.js absent');
  } else if (!_sameBytes(worker, workerSource)) {
    problems.add('drift_worker.js différent de celui du paquet drift résolu');
  }
  if (!wasm.existsSync()) {
    problems.add('app/web/sqlite3.wasm absent');
  } else if (!_isWasm(wasm)) {
    problems.add("app/web/sqlite3.wasm n'est pas un module WebAssembly");
  }
  final recorded = versionFile.existsSync()
      ? versionFile.readAsStringSync().trim()
      : null;
  if (recorded != sqliteVersion) {
    problems.add(
      'sqlite3.wasm de la version ${recorded ?? 'inconnue'}, '
      'sqlite3 verrouillé en $sqliteVersion',
    );
  }
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    stderr.writeln('Lancer : dart run scripts/sync_web_assets.dart');
    exit(1);
  }
  stdout.writeln(
    'Fichiers web drift : drift_worker.js identique au paquet, '
    'sqlite3.wasm $sqliteVersion.',
  );
}

String _lockedVersion(String package) {
  final lock = File('$_root/app/pubspec.lock').readAsStringSync();
  final match = RegExp(
    '^  $package:\\n(?:    .*\\n)*?    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lock);
  if (match == null) {
    stderr.writeln('$package absent de app/pubspec.lock');
    exit(1);
  }
  return match.group(1)!;
}

String _packageDir(String package) {
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
  final entry = packages.firstWhere((p) => p['name'] == package);
  final root = Uri.parse(entry['rootUri'] as String);
  return config.parent.uri.resolveUri(root).toFilePath();
}

bool _sameBytes(File a, File b) {
  final left = a.readAsBytesSync();
  final right = b.readAsBytesSync();
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _isWasm(File file) {
  final head = file.openSync().readSync(_wasmMagic.length);
  return head.length == _wasmMagic.length &&
      List.generate(
        _wasmMagic.length,
        (i) => head[i] == _wasmMagic[i],
      ).every((ok) => ok);
}
