import 'dart:math' as math;

import 'model.dart';
import 'placement.dart';

const int _cellCols = 12;
const _cellRows = 6;
const _marginCols = 6; // 0,5 case de tolérance autour de la surface
const _marginRows = 3;
const int _gridCols = 8 * _cellCols + 1 + 2 * _marginCols;
const int _gridRows = 4 * _cellRows + 1 + 2 * _marginRows;

const Map<String, String> _colorLetters = {
  'red': 'R',
  'yellow': 'Y',
  'black': 'B',
  'white': 'W',
};

/// Rend un diagramme en ASCII (surface 8x4 sur 97 x 25 caractères, plus une
/// marge de tolérance), suivi d'une légende textuelle exhaustive.
String renderAscii(Json diagram) {
  final out = StringBuffer('# ${diagram['id']} (${diagram['kind']})\n');
  if (diagram.containsKey('balls') || diagram.containsKey('table')) {
    out.writeln(_Canvas(diagram).render());
  }
  _legend(diagram).forEach(out.writeln);
  return out.toString().trimRight();
}

int _col(double x) => _marginCols + (x * _cellCols).round();
int _row(double y) => _marginRows + (y * _cellRows).round();

class _Canvas {
  _Canvas(this.d)
    : _cells = List.generate(_gridRows, (_) => List.filled(_gridCols, ' '));

  final Json d;
  final List<List<String>> _cells;

  void _put(int r, int c, String ch) {
    if (r < 0 || r >= _gridRows || c < 0 || c >= _gridCols) return;
    _cells[r][c] = ch;
  }

  void _text(int r, int c, String s) {
    for (var i = 0; i < s.length; i++) {
      _put(r, c + i, s[i]);
    }
  }

  String render() {
    _zones();
    _frame();
    final heads = _arrows();
    _pockets();
    for (final cell in heads) {
      _put(cell.$1, cell.$2, '>');
    }
    _ghosts();
    _balls();
    return _cells.map((r) => r.join().trimRight()).join('\n');
  }

  void _frame() {
    final left = _col(0);
    final right = _col(tableLength);
    final top = _row(0);
    final bottom = _row(tableWidth);
    for (var c = left; c <= right; c++) {
      _put(top, c, '-');
      _put(bottom, c, '-');
    }
    for (var r = top; r <= bottom; r++) {
      _put(r, left, '|');
      _put(r, right, '|');
    }
    final start = _col(startLineX);
    for (var r = top + 1; r < bottom; r++) {
      _put(r, start, '|');
    }
    for (final (r, c) in [
      (top, left),
      (top, right),
      (bottom, left),
      (bottom, right),
    ]) {
      _put(r, c, '+');
    }
  }

  void _pockets() {
    for (final p in pockets.values) {
      _put(_row(p[1]), _col(p[0]), 'O');
    }
  }

  void _zones() {
    for (final z in mapsOf(d, 'zones')) {
      bool Function(double x, double y)? inside;
      switch (z['shape']) {
        case 'rect':
          final a = pointOf(z['from']);
          final b = pointOf(z['to']);
          if (a != null && b != null) {
            inside = (x, y) =>
                x >= math.min(a[0], b[0]) &&
                x <= math.max(a[0], b[0]) &&
                y >= math.min(a[1], b[1]) &&
                y <= math.max(a[1], b[1]);
          }
        case 'circle':
          final c = pointOf(z['at']);
          final r = z['radius'];
          if (c != null && r is num) {
            inside = (x, y) =>
                math.pow(x - c[0], 2) + math.pow(y - c[1], 2) <= math.pow(r, 2);
          }
        case 'polygon':
          final pts = [
            for (final p in (z['points'] as List<Object?>? ?? const []))
              ?pointOf(p),
          ];
          if (pts.length >= 3) inside = (x, y) => _inPolygon(pts, x, y);
      }
      if (inside == null) continue;
      for (var r = 0; r < _gridRows; r++) {
        for (var c = 0; c < _gridCols; c++) {
          final x = (c - _marginCols) / _cellCols;
          final y = (r - _marginRows) / _cellRows;
          if (inside(x, y) && (r + c) % 3 == 0) _put(r, c, '/');
        }
      }
    }
  }

  /// Trace les flèches ; retourne la cellule de la pointe de chacune.
  List<(int, int)> _arrows() {
    final pocketCells = {
      for (final p in pockets.values) (_row(p[1]), _col(p[0])),
    };
    final heads = <(int, int)>[];
    for (final a in mapsOf(d, 'arrows')) {
      final route = a['path'];
      if (route is! List<Object?>) continue;
      final pts = [for (final p in route) ?pointOf(p)];
      final cells = <(int, int)>[];
      for (var i = 0; i < pts.length; i++) {
        final to = (_row(pts[i][1]), _col(pts[i][0]));
        if (i == 0) {
          cells.add(to);
          continue;
        }
        final from = cells.last;
        final steps = math.max(
          (to.$1 - from.$1).abs(),
          (to.$2 - from.$2).abs(),
        );
        for (var s = 1; s <= steps; s++) {
          cells.add((
            from.$1 + ((to.$1 - from.$1) * s / steps).round(),
            from.$2 + ((to.$2 - from.$2) * s / steps).round(),
          ));
        }
      }
      if (cells.isEmpty) continue;
      for (final c in cells) {
        _put(c.$1, c.$2, '.');
      }
      var head = cells.last;
      if (pocketCells.contains(head) && cells.length > 1) {
        head = cells[cells.length - 2];
      }
      heads.add(head);
    }
    return heads;
  }

  void _ghosts() {
    for (final g in mapsOf(d, 'ghosts')) {
      final p = pointOf(g['at']);
      if (p == null) continue;
      final label = g['label'] == null ? '' : '${g['label']}';
      final text = '($label)';
      _text(_row(p[1]), _col(p[0]) - text.length ~/ 2, text);
    }
  }

  void _balls() {
    for (final b in mapsOf(d, 'balls')) {
      final p = pointOf(b['at']);
      if (p == null) continue;
      final letter = _colorLetters['${b['color']}'] ?? '?';
      final label = b['label'] == null ? '' : '${b['label']}';
      _text(_row(p[1]), _col(p[0]), '$letter$label');
    }
  }
}

bool _inPolygon(List<List<double>> pts, double x, double y) {
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final a = pts[i];
    final b = pts[j];
    final crosses =
        (a[1] > y) != (b[1] > y) &&
        x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0];
    if (crosses) inside = !inside;
  }
  return inside;
}

List<String> _legend(Json d) {
  final lines = <String>[];
  void section(String title, List<String> items) {
    if (items.isEmpty) return;
    lines
      ..add('$title :')
      ..addAll(items.map((s) => '  $s'));
  }

  void field(String label, Object? v) {
    if (v == null) return;
    if (v is List) {
      section(label, [for (final e in v) '$e']);
    } else {
      lines.add('$label : $v');
    }
  }

  field('Légende', d['caption']);
  field('Fiche', d['sheet']);
  field('Exercice', d['exercise']);
  field('Chevalet', d['bridge']);
  final rate = d['success_rate'];
  if (rate is List) lines.add('Taux de réussite : ${rate.join('/')}');
  if (d.containsKey('balls') || d.containsKey('table')) {
    lines.add(
      'Table : 8 x 4 cases, vue de dessus, départ à gauche ; ligne de '
      'départ x=${fmt(startLineX)} ; poches O ; y vers le bas',
    );
  }
  section('Billes', [for (final b in mapsOf(d, 'balls')) _ballLine(b)]);
  section('Ghosts', [for (final g in mapsOf(d, 'ghosts')) _ghostLine(g)]);
  section('Flèches', [for (final a in mapsOf(d, 'arrows')) _arrowLine(a)]);
  section('Zones', [for (final z in mapsOf(d, 'zones')) _zoneLine(z)]);
  section('Séquence', [for (final s in mapsOf(d, 'sequence')) _stepLine(s)]);
  final inset = d['inset'];
  if (inset is Map) {
    final parts = inset.entries.map((e) => '${e.key}=${e.value}');
    lines.add('Quantité de bille : ${parts.join(', ')}');
  }
  for (final key in ['subject', 'teaching_point', 'adjacent_text_summary']) {
    field(key, d[key]);
  }
  field('elements', d['elements']);
  field('annotations', d['annotations']);
  field('Description', d['description']);
  field('Incertitudes', d['uncertainties']);
  for (final w in placementWarnings(d)) {
    lines.add('AVERTISSEMENT : $w');
  }
  return lines;
}

String _at(Object? v) {
  final p = pointOf(v);
  return p == null ? '?' : fmtPoint(p);
}

String _label(Json m) => m['label'] == null ? '' : ' label "${m['label']}"';

String _ballLine(Json b) {
  final role = b['role'] == null ? '' : ' role ${b['role']}';
  return '${b['id']}  ${b['color']} ${_at(b['at'])}${_label(b)}$role';
}

String _ghostLine(Json g) {
  final target = g['for'] == null ? '' : ' pour ${g['for']}';
  return '${g['id']}  ${g['role']} ${_at(g['at'])}${_label(g)}$target';
}

String _arrowLine(Json a) {
  final bounces = _listOf(a['bounces']);
  final rebounds = bounces.isEmpty ? '' : ' rebonds ${bounces.join(',')}';
  final to = a['to'] == null ? '' : ' vers poche ${a['to']}';
  return '${a['id']}  ${a['kind']} bille ${a['ball']} : '
      '${_route(a['path'])}$rebounds$to';
}

String _zoneLine(Json z) {
  final geometry = switch (z['shape']) {
    'rect' => '${_at(z['from'])} -> ${_at(z['to'])}',
    'circle' => 'centre ${_at(z['at'])} rayon ${z['radius']}',
    _ => _route(z['points']),
  };
  return '${z['id']}  ${z['shape']} $geometry${_label(z)}';
}

String _stepLine(Json s) =>
    'étape ${s['step']} : ${s['cue']} touche ${s['hit']}, '
    'contact ${s['contact']}, poche ${s['pocket']}, x${s['repeat'] ?? 1}';

List<Object?> _listOf(Object? v) => v is List<Object?> ? v : const [];

String _route(Object? path) {
  final pts = [for (final p in _listOf(path)) ?pointOf(p)];
  return pts.map(fmtPoint).join(' -> ');
}
