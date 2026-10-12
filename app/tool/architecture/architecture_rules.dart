// Vérificateur d'architecture déterministe (Clean Architecture + FSD).
//
// Pur Dart (dart:io uniquement) : aucune dépendance, exécutable en quelques
// centaines de millisecondes via `dart run tool/check_architecture.dart`.
import 'dart:io';

/// Couches FSD, de la plus haute à la plus basse. Une couche ne peut importer
/// que des couches strictement inférieures (ou sa propre slice).
const layers = <String>[
  'app',
  'pages',
  'widgets',
  'features',
  'entities',
  'shared',
];

/// Segments Clean Architecture autorisés dans une slice.
const segments = <String>['domain', 'data', 'presentation'];

/// Imports tolérés dans `domain` et `shared/lib` (code Dart pur).
const _pureAllowedPrefixes = <String>[
  'dart:core',
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:math',
  'package:freezed_annotation/',
  'package:injectable/',
  'package:meta/',
];

class Violation {
  const Violation(this.file, this.line, this.message);

  final String file;
  final int line;
  final String message;

  @override
  String toString() => '$file:$line: $message';
}

class _Location {
  const _Location(this.layer, this.slice, this.segment);

  final String layer;
  final String? slice;
  final String? segment;
}

final _directive = RegExp(
  r'''^\s*(import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.steps.dart') ||
    path.contains('/l10n/generated/');

/// Analyse un chemin relatif à `lib/` (ex. `features/plan_session/domain/x.dart`).
_Location? _locate(List<String> parts) {
  if (parts.length < 2) return null;
  final layer = parts.first;
  if (!layers.contains(layer)) return null;
  if (layer == 'app') return _Location(layer, null, null);
  if (layer == 'shared') {
    return _Location(layer, null, parts.length > 2 ? parts[1] : null);
  }
  final slice = parts[1];
  final segment = parts.length > 3 ? parts[2] : null;
  return _Location(layer, slice, segment);
}

List<Violation> checkArchitecture(
  Directory lib, {
  String packageName = 'billard_cfa',
}) {
  final violations = <Violation>[];
  final prefix = 'package:$packageName/';
  final root = lib.absolute.path;

  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.absolute.path
        .substring(root.length + 1)
        .replaceAll(r'\', '/');
    if (_isGenerated(relative)) continue;
    final display = 'lib/$relative';

    void report(int line, String message) =>
        violations.add(Violation(display, line, message));

    final parts = relative.split('/');
    // main.dart est le point d'entrée : traité comme la couche `app`.
    final source = relative == 'main.dart'
        ? const _Location('app', null, null)
        : _locate(parts);
    if (source == null) {
      report(1, 'fichier hors structure FSD (couches: ${layers.join(', ')})');
      continue;
    }
    if (source.layer != 'app' && source.layer != 'shared') {
      if (parts.length < 4) {
        report(1, 'un fichier doit être dans <couche>/<slice>/<segment>/');
        continue;
      }
      if (!segments.contains(source.segment)) {
        report(
          1,
          'segment "${source.segment}" inconnu '
          '(attendu: ${segments.join(', ')})',
        );
        continue;
      }
    }

    final text = entity.readAsStringSync();
    final isPure =
        source.segment == 'domain' ||
        (source.layer == 'shared' && source.segment == 'lib');

    for (final match in _directive.allMatches(text)) {
      final uri = match.group(2)!;
      final line = '\n'.allMatches(text.substring(0, match.start)).length + 1;

      if (!uri.startsWith('dart:') && !uri.startsWith('package:')) {
        report(line, 'import relatif interdit ($uri) : utiliser package:');
        continue;
      }
      if (isPure) {
        final allowed =
            uri.startsWith(prefix) || _pureAllowedPrefixes.any(uri.startsWith);
        if (!allowed) {
          report(line, 'code domain/shared.lib non pur : import "$uri"');
          continue;
        }
      }
      if (!uri.startsWith(prefix)) continue;

      final targetParts = uri.substring(prefix.length).split('/');
      if (targetParts.length == 1 && targetParts.first == 'main.dart') {
        report(line, 'import de main.dart interdit');
        continue;
      }
      final target = _locate(targetParts);
      if (target == null) {
        report(line, 'import hors structure FSD ($uri)');
        continue;
      }
      _checkImport(source, target, uri, line, report, isPure);
    }
  }
  return violations;
}

void _checkImport(
  _Location source,
  _Location target,
  String uri,
  int line,
  void Function(int, String) report,
  bool sourceIsPure,
) {
  final sourceRank = layers.indexOf(source.layer);
  final targetRank = layers.indexOf(target.layer);

  if (targetRank < sourceRank) {
    report(
      line,
      'la couche ${source.layer} ne peut pas importer la couche '
      '${target.layer} ($uri)',
    );
    return;
  }
  final sameSlice =
      source.layer == target.layer &&
      source.slice == target.slice &&
      source.layer != 'app';
  if (source.layer == target.layer &&
      source.layer != 'app' &&
      source.layer != 'shared' &&
      !sameSlice) {
    report(
      line,
      'import entre slices de la même couche '
      '(${source.layer}/${source.slice} -> ${target.slice}) : $uri',
    );
    return;
  }

  // La couche app câble tout (DI, routeur) : pas de règle de segment.
  if (source.layer == 'app') return;

  if (target.layer == 'shared') {
    if (source.layer == 'shared') {
      _checkSharedImport(source, target, uri, line, report);
      return;
    }
    if (source.segment == 'domain' && target.segment != 'lib') {
      report(line, 'domain ne peut importer que shared/lib ($uri)');
    } else if (target.segment == 'persistence' && source.segment != 'data') {
      report(
        line,
        'shared/persistence est réservé à data et à la couche app ($uri)',
      );
    }
    return;
  }

  switch (source.segment) {
    case 'domain':
      if (target.segment != 'domain') {
        report(line, 'domain ne peut importer que du domain ($uri)');
      }
    case 'data':
      if (target.segment != 'domain' &&
          !(sameSlice && target.segment == 'data')) {
        report(
          line,
          'data ne peut importer que du domain ou sa propre data ($uri)',
        );
      }
    case 'presentation':
      if (target.segment == 'data') {
        report(line, 'presentation ne doit jamais importer data ($uri)');
      }
  }
}

/// Imports entre segments de `shared` : `lib` est le noyau pur (n'importe que
/// `lib`) ; `persistence` ne dépend que de `lib` ; `ui` et `l10n` ne touchent
/// jamais `persistence`.
void _checkSharedImport(
  _Location source,
  _Location target,
  String uri,
  int line,
  void Function(int, String) report,
) {
  if (source.segment == target.segment) return;
  if (source.segment == 'lib') {
    report(line, 'shared/lib ne peut importer que shared/lib ($uri)');
  } else if (source.segment == 'persistence' && target.segment != 'lib') {
    report(line, 'shared/persistence ne peut importer que shared/lib ($uri)');
  } else if (target.segment == 'persistence') {
    report(
      line,
      'shared/persistence est réservé à data et à la couche app ($uri)',
    );
  }
}
