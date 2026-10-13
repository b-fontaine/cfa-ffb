import 'package:yaml/yaml.dart';

import 'model.dart';
import 'placement.dart';

/// Valide le contenu YAML d'un fichier de diagrammes (une page de PDF).
ValidationReport validateDiagramFile(String text) {
  final Object? doc;
  try {
    doc = toPlain(loadYaml(text));
  } on YamlException catch (e) {
    return ValidationReport(errors: ['YAML invalide : ${e.message}']);
  }
  final checker = _Checker();
  if (doc is! Map<String, Object?>) {
    return ValidationReport(errors: ['racine : objet YAML attendu']);
  }
  checker.file(doc);
  final diagrams = mapsOf(doc, 'diagrams');
  final warnings = <String>[
    if (checker.errors.isEmpty)
      for (final d in diagrams)
        for (final w in placementWarnings(d)) '${d['id']} : $w',
  ];
  return ValidationReport(
    errors: checker.errors,
    warnings: warnings,
    diagrams: diagrams,
  );
}

class _Checker {
  final errors = <String>[];

  void _err(String path, String message) => errors.add('$path : $message');

  void file(Json doc) {
    if (!_isPositiveInt(doc['version'])) {
      _err('version', 'entier positif obligatoire');
    }
    final source = doc['source'];
    if (source is! Map<String, Object?>) {
      _err('source', 'objet obligatoire (file, page)');
    } else {
      if (!_isNonEmptyString(source['file'])) {
        _err('source.file', 'texte obligatoire');
      }
      if (!_isPositiveInt(source['page'])) {
        _err('source.page', 'entier positif obligatoire');
      }
      // `S` : transcription d'un PDF ; `Prop` : page proposée, hors PDF
      // (dossier proposition/, voir FORMAT.md § 3).
      if (source.containsKey('rank') && !sourceRanks.contains(source['rank'])) {
        _err(
          'source.rank',
          'valeur inconnue : ${source['rank']} (attendu : '
              '${sourceRanks.join(' | ')})',
        );
      }
    }
    final diagrams = doc['diagrams'];
    if (diagrams is! List) {
      _err('diagrams', 'liste obligatoire');
      return;
    }
    if (diagrams.isEmpty && doc['no_illustration'] != true) {
      _err('diagrams', 'liste vide : no_illustration: true obligatoire');
    }
    final ids = <String>{};
    for (var i = 0; i < diagrams.length; i++) {
      final d = diagrams[i];
      final path = 'diagrams[$i]';
      if (d is! Map<String, Object?>) {
        _err(path, 'objet attendu');
        continue;
      }
      _diagram(d, path, ids);
    }
  }

  void _diagram(Json d, String path, Set<String> ids) {
    final id = d['id'];
    if (!_isNonEmptyString(id)) {
      _err('$path.id', 'texte obligatoire');
    } else if (!ids.add(id! as String)) {
      _err('$path.id', 'id dupliqué dans le fichier : $id');
    }
    final kind = d['kind'];
    _enum('$path.kind', kind, diagramKinds);
    final isPhoto = kind == 'technique-photo';
    final hasCaption = _isNonEmptyString(d['caption']);
    if (!hasCaption && !isPhoto) _err('$path.caption', 'texte obligatoire');
    if (!hasCaption && !_isNonEmptyString(d['description'])) {
      _err(path, 'caption ou description obligatoire');
    }
    if (!_isNonEmptyString(d['description'])) {
      _err('$path.description', 'texte obligatoire');
    }
    if (d['uncertainties'] is! List) {
      _err('$path.uncertainties', 'liste obligatoire (éventuellement vide)');
    }
    if (d.containsKey('bridge')) _enum('$path.bridge', d['bridge'], bridges);
    if (d.containsKey('exercise') && !_isPositiveInt(d['exercise'])) {
      _err('$path.exercise', 'entier positif attendu');
    }
    if (d.containsKey('bronze') && d['bronze'] is! bool) {
      _err('$path.bronze', 'booléen attendu');
    }
    if (d.containsKey('success_rate')) _successRate('$path.success_rate', d);
    if (kind is String && tableKinds.contains(kind)) {
      if (d['balls'] is! List) _err('$path.balls', 'liste obligatoire');
      if (d['table'] is! Map) _err('$path.table', 'objet obligatoire');
    }
    final ballIds = _balls(d, path);
    _ghosts(d, path, ballIds);
    _arrows(d, path, ballIds);
    _zones(d, path);
    _sequence(d, path, ballIds);
    _inset(d, path);
  }

  void _successRate(String path, Json d) {
    final v = d['success_rate'];
    final ok =
        v is List &&
        v.length == 2 &&
        _isPositiveInt(v[0]) &&
        _isPositiveInt(v[1]) &&
        (v[0]! as int) <= (v[1]! as int);
    if (!ok) {
      _err(
        path,
        '[réussites, tentatives] entiers positifs, réussites <= tentatives',
      );
    }
  }

  Set<String> _balls(Json d, String path) {
    final ids = <String>{};
    for (final (i, b) in _items(d, 'balls', path)) {
      final p = '$path.balls[$i]';
      final id = b['id'];
      if (!_isNonEmptyString(id)) {
        _err('$p.id', 'texte obligatoire');
      } else if (!ids.add(id! as String)) {
        _err('$p.id', 'id dupliqué : $id');
      }
      _enum('$p.color', b['color'], ballColors);
      _point('$p.at', b['at']);
    }
    return ids;
  }

  void _ghosts(Json d, String path, Set<String> ballIds) {
    final ids = <String>{};
    for (final (i, g) in _items(d, 'ghosts', path)) {
      final p = '$path.ghosts[$i]';
      _uniqueId('$p.id', g['id'], ids);
      _enum('$p.role', g['role'], ghostRoles);
      _point('$p.at', g['at']);
      if (g.containsKey('for')) _ref('$p.for', g['for'], ballIds);
    }
  }

  void _arrows(Json d, String path, Set<String> ballIds) {
    final ids = <String>{};
    for (final (i, a) in _items(d, 'arrows', path)) {
      final p = '$path.arrows[$i]';
      _uniqueId('$p.id', a['id'], ids);
      _enum('$p.kind', a['kind'], arrowKinds);
      if (a.containsKey('ball') || a['kind'] != 'indication') {
        _ref('$p.ball', a['ball'], ballIds);
      }
      final route = a['path'];
      if (route is! List || route.length < 2) {
        _err('$p.path', 'liste de 2 points au moins obligatoire');
      } else {
        for (var j = 0; j < route.length; j++) {
          _point('$p.path[$j]', route[j]);
        }
      }
      final bounces = a['bounces'];
      if (bounces != null) {
        if (bounces is! List) {
          _err('$p.bounces', 'liste attendue');
        } else {
          for (var j = 0; j < bounces.length; j++) {
            _enum('$p.bounces[$j]', bounces[j], bands);
          }
        }
      }
      if (a.containsKey('to')) _enum('$p.to', a['to'], pockets.keys.toSet());
    }
  }

  void _zones(Json d, String path) {
    final ids = <String>{};
    for (final (i, z) in _items(d, 'zones', path)) {
      final p = '$path.zones[$i]';
      _uniqueId('$p.id', z['id'], ids);
      final shape = z['shape'];
      _enum('$p.shape', shape, zoneShapes);
      switch (shape) {
        case 'rect':
          _point('$p.from', z['from']);
          _point('$p.to', z['to']);
        case 'circle':
          _point('$p.at', z['at']);
          final r = z['radius'];
          if (r is! num || r <= 0) {
            _err('$p.radius', 'nombre positif obligatoire');
          }
        case 'polygon':
          final pts = z['points'];
          if (pts is! List || pts.length < 3) {
            _err('$p.points', 'liste de 3 points au moins obligatoire');
          } else {
            for (var j = 0; j < pts.length; j++) {
              _point('$p.points[$j]', pts[j]);
            }
          }
      }
    }
  }

  void _sequence(Json d, String path, Set<String> ballIds) {
    for (final (i, s) in _items(d, 'sequence', path)) {
      final p = '$path.sequence[$i]';
      if (!_isPositiveInt(s['step'])) {
        _err('$p.step', 'entier positif obligatoire');
      }
      _ref('$p.cue', s['cue'], ballIds);
      if (s.containsKey('hit')) _ref('$p.hit', s['hit'], ballIds);
      if (s.containsKey('contact')) _enum('$p.contact', s['contact'], contacts);
      if (s.containsKey('pocket')) {
        _enum('$p.pocket', s['pocket'], pockets.keys.toSet());
      }
      if (s.containsKey('repeat') && !_isPositiveInt(s['repeat'])) {
        _err('$p.repeat', 'entier positif attendu');
      }
    }
  }

  void _inset(Json d, String path) {
    final inset = d['inset'];
    if (inset == null) return;
    if (inset is! Map<String, Object?>) {
      _err('$path.inset', 'objet attendu');
      return;
    }
    if (inset.containsKey('contact')) {
      _enum('$path.inset.contact', inset['contact'], contacts);
    }
  }

  /// Éléments objets d'une liste optionnelle, avec leur index.
  Iterable<(int, Json)> _items(Json d, String key, String path) sync* {
    final v = d[key];
    if (v == null) return;
    if (v is! List) {
      _err('$path.$key', 'liste attendue');
      return;
    }
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is Map<String, Object?>) {
        yield (i, e);
      } else {
        _err('$path.$key[$i]', 'objet attendu');
      }
    }
  }

  void _uniqueId(String path, Object? id, Set<String> seen) {
    if (!_isNonEmptyString(id)) {
      _err(path, 'texte obligatoire');
    } else if (!seen.add(id! as String)) {
      _err(path, 'id dupliqué : $id');
    }
  }

  void _enum(String path, Object? value, Set<String> allowed) {
    if (value is! String || !allowed.contains(value)) {
      _err(path, 'valeur inconnue : $value (attendu : ${allowed.join(' | ')})');
    }
  }

  void _ref(String path, Object? value, Set<String> ids) {
    if (value is! String || !ids.contains(value)) {
      _err(path, 'référence inconnue : $value (billes : ${ids.join(', ')})');
    }
  }

  void _point(String path, Object? value) {
    final p = pointOf(value);
    if (p == null) {
      _err(path, 'point [x, y] numérique obligatoire');
    } else if (p[0] < minX || p[0] > maxX || p[1] < minY || p[1] > maxY) {
      _err(
        path,
        'coordonnées ${fmtPoint(p)} hors de [$minX, $maxX] x [$minY, $maxY]',
      );
    }
  }

  bool _isPositiveInt(Object? v) => v is int && v > 0;

  bool _isNonEmptyString(Object? v) => v is String && v.trim().isNotEmpty;
}
