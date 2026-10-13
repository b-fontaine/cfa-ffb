import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:yaml/yaml.dart';

/// Une page de transcription ne respecte pas le FORMAT (`FORMAT.md`) ou
/// contient ce que le modèle ne représente pas sans perte.
///
/// Le message nomme le diagramme et le champ en cause.
class InvalidDiagramPage implements Exception {
  const InvalidDiagramPage(this.message);

  final String message;

  @override
  String toString() => 'InvalidDiagramPage($message)';
}

typedef _Json = Map<String, Object?>;

const _kinds = <String, DiagramKind>{
  'exercise': DiagramKind.exercise,
  'game': DiagramKind.game,
  'initiation': DiagramKind.initiation,
};

const _stepKeys = {'step', 'cue', 'hit', 'contact', 'pocket', 'repeat', 'from'};

/// Lit une page de transcription (`docs/knowledge/03-exercices/diagrammes/`,
/// un fichier `pNN.yaml` par page de PDF) et construit ses schémas de table.
///
/// Les diagrammes sans table (`technique-photo`, `technique-schema`) sont
/// ignorés. Tout champ d'une bille, d'un cercle, d'une flèche, d'une zone ou
/// d'un tir que le modèle ne représente pas est refusé : la lecture ne perd
/// jamais d'information sans le dire.
///
/// Lève [InvalidDiagramPage] pour toute structure inattendue.
List<ExerciseDiagram> parseDiagramPage(String source) {
  final Object? root;
  try {
    root = _plain(loadYaml(source));
  } on YamlException catch (e) {
    throw InvalidDiagramPage('YAML invalide : ${e.message}');
  }
  if (root is! _Json) {
    throw const InvalidDiagramPage('racine : objet YAML attendu');
  }
  final origin = root['source'];
  final file = origin is Map ? origin['file'] : null;
  final page = origin is Map ? origin['page'] : null;
  if (file is! String || page is! int) {
    throw const InvalidDiagramPage('source : file (texte) et page (entier)');
  }
  final diagrams = root['diagrams'];
  if (diagrams is! List) {
    throw const InvalidDiagramPage('diagrams : liste attendue');
  }
  return [
    for (final raw in diagrams)
      if (raw is! _Json)
        throw InvalidDiagramPage('diagrams : objet attendu, trouvé : $raw')
      else if (_kinds.containsKey(raw['kind']))
        _parseDiagram(raw, file: file, page: page),
  ];
}

Object? _plain(Object? node) {
  if (node is Map) {
    return <String, Object?>{
      for (final e in node.entries) '${e.key}': _plain(e.value),
    };
  }
  if (node is List) return [for (final v in node) _plain(v)];
  return node;
}

/// Lecture d'un objet qui garde la trace des champs consommés.
class _Fields {
  _Fields(this._map, this._where);

  final _Json _map;
  final String _where;
  final _read = <String>{};

  Object? operator [](String key) {
    _read.add(key);
    return _map[key];
  }

  Never fail(String key, String problem) =>
      throw InvalidDiagramPage('$_where.$key : $problem');

  String str(String key) {
    final v = this[key];
    if (v is String && v.trim().isNotEmpty) return v;
    fail(key, 'texte attendu, trouvé : $v');
  }

  String? optStr(String key) {
    final v = this[key];
    return v == null ? null : '$v';
  }

  int? optInt(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is int) return v;
    fail(key, 'entier attendu, trouvé : $v');
  }

  E? optEnum<E extends Enum>(List<E> values, String key) {
    final v = this[key];
    return v == null ? null : _enumOf(values, v, () => fail(key, 'inconnu'));
  }

  E enumOf<E extends Enum>(List<E> values, String key) {
    final v = this[key];
    return _enumOf(
      values,
      v,
      () => fail(key, 'valeur inconnue du modèle : $v'),
    );
  }

  TablePoint point(String key) => _point(this[key], () => fail(key, 'point'));

  List<TablePoint> points(String key) {
    final v = this[key];
    if (v is! List) fail(key, 'liste attendue');
    return [for (final e in v) _point(e, () => fail(key, 'point : $e'))];
  }

  /// Marque tous les champs comme lus (ceux du tir sont portés par `extras`).
  void touchAll() => _read.addAll(_map.keys);

  void expectNoneLeft() {
    final left = _map.keys.where((k) => !_read.contains(k)).toList();
    if (left.isNotEmpty) {
      throw InvalidDiagramPage(
        '$_where : champs non représentés par le modèle : ${left.join(', ')}',
      );
    }
  }
}

String _snake(Enum e) =>
    e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

E _enumOf<E extends Enum>(List<E> values, Object? raw, Never Function() fail) {
  for (final v in values) {
    if (_snake(v) == raw) return v;
  }
  fail();
}

TablePoint _point(Object? raw, Never Function() fail) {
  if (raw is List && raw.length == 2) {
    final x = raw[0];
    final y = raw[1];
    if (x is num && y is num) return TablePoint(x.toDouble(), y.toDouble());
  }
  fail();
}

List<_Json> _objects(_Fields f, String key) {
  final v = f[key];
  if (v == null) return const [];
  if (v is! List) f.fail(key, 'liste attendue');
  return [
    for (final e in v)
      if (e is _Json) e else f.fail(key, 'objet attendu, trouvé : $e'),
  ];
}

List<String> _strings(_Fields f, String key) {
  final v = f[key];
  if (v == null) return const [];
  if (v is! List) f.fail(key, 'liste attendue');
  return [for (final e in v) '$e'];
}

ExerciseDiagram _parseDiagram(
  _Json raw, {
  required String file,
  required int page,
}) {
  final f = _Fields(raw, '${raw['id']}');
  try {
    return _build(f, file: file, page: page);
  } on InvalidDiagramPage catch (e) {
    throw InvalidDiagramPage('[${raw['id']}] ${e.message}');
  } on Failure catch (e) {
    throw InvalidDiagramPage('[${raw['id']}] valeur hors bornes : $e');
  }
}

ExerciseDiagram _build(_Fields f, {required String file, required int page}) {
  final rate = f['success_rate'];
  SuccessRate? successRate;
  if (rate != null) {
    if (rate is! List ||
        rate.length != 2 ||
        rate[0] is! int ||
        rate[1] is! int) {
      f.fail('success_rate', 'deux entiers attendus, trouvé : $rate');
    }
    successRate = SuccessRate(
      successes: rate[0] as int,
      attempts: rate[1] as int,
    );
  }
  final bronze = f['bronze'];
  if (bronze != null && bronze is! bool) {
    f.fail('bronze', 'booléen attendu, trouvé : $bronze');
  }
  final id = f.str('id');
  final steps = _steps(f);
  return ExerciseDiagram(
    id: id,
    kind: _kinds[f['kind']]!,
    sheet: f.str('sheet'),
    exercise: f.optInt('exercise'),
    caption: f.str('caption'),
    description: f.str('description'),
    sourceFile: file,
    sourcePage: page,
    successRate: successRate,
    bridge: f.optEnum(DiagramBridge.values, 'bridge'),
    bronze: bronze == true,
    annotations: _strings(f, 'annotations'),
    uncertainties: _strings(f, 'uncertainties'),
    table: DiagramTable(
      balls: _balls(f),
      ghosts: _ghosts(f),
      arrows: _arrows(f),
      zones: _zones(f),
      steps: steps,
    ),
  );
}

List<TableBall> _balls(_Fields d) {
  final raw = d['balls'];
  if (raw is! List) d.fail('balls', 'liste obligatoire pour une table');
  return [
    for (final (i, b) in _objects(d, 'balls').indexed)
      () {
        final f = _Fields(b, 'balls[$i]');
        final ball = TableBall(
          id: f.str('id'),
          color: f.enumOf(TableBallColor.values, 'color'),
          at: f.point('at'),
          role: f.optEnum(TableBallRole.values, 'role'),
          label: f.optStr('label'),
          order: f.optInt('order'),
        );
        f.expectNoneLeft();
        return ball;
      }(),
  ];
}

List<TableGhost> _ghosts(_Fields d) => [
  for (final (i, g) in _objects(d, 'ghosts').indexed)
    () {
      final f = _Fields(g, 'ghosts[$i]');
      final ghost = TableGhost(
        id: f.str('id'),
        at: f.point('at'),
        role: f.enumOf(TableGhostRole.values, 'role'),
        forBallId: f.optStr('for'),
        label: f.optStr('label'),
      );
      f.expectNoneLeft();
      return ghost;
    }(),
];

List<TableArrow> _arrows(_Fields d) => [
  for (final (i, a) in _objects(d, 'arrows').indexed)
    () {
      final f = _Fields(a, 'arrows[$i]');
      final bounces = f['bounces'];
      if (bounces != null && bounces is! List) {
        f.fail('bounces', 'liste attendue');
      }
      final arrow = TableArrow(
        id: f.str('id'),
        kind: f.enumOf(TableArrowKind.values, 'kind'),
        path: f.points('path'),
        ballId: f.optStr('ball'),
        bounces: [
          if (bounces is List)
            for (final band in bounces)
              _enumOf(
                TableBand.values,
                band,
                () => f.fail('bounces', 'bande inconnue : $band'),
              ),
        ],
        pocket: f.optEnum(TablePocket.values, 'to'),
        label: f.optStr('label'),
        note: f.optStr('note'),
      );
      f.expectNoneLeft();
      return arrow;
    }(),
];

List<TableZone> _zones(_Fields d) => [
  for (final (i, z) in _objects(d, 'zones').indexed)
    () {
      final f = _Fields(z, 'zones[$i]');
      final shape = f['shape'];
      if (shape != 'rect') {
        f.fail(
          'shape',
          'seuls les rectangles sont représentés, trouvé : $shape',
        );
      }
      final zone = TableZone(
        id: f.str('id'),
        from: f.point('from'),
        to: f.point('to'),
        label: f.optStr('label'),
      );
      f.expectNoneLeft();
      return zone;
    }(),
];

List<TableStep> _steps(_Fields d) => [
  for (final (i, s) in _objects(d, 'sequence').indexed)
    () {
      final f = _Fields(s, 'sequence[$i]');
      if (f['step'] != i + 1) {
        f.fail(
          'step',
          '${s['step']} au lieu de ${i + 1} '
              "(le modèle garde l'ordre, pas le numéro)",
        );
      }
      final cue = f.str('cue');
      final contact = f['contact'];
      // `from: <bille jouée>` = départ de la bille elle-même, c'est le défaut.
      final from = f.optStr('from');
      final step = TableStep(
        cueId: cue,
        hitId: f.optStr('hit'),
        contact: contact == 'none'
            ? null
            : f.optEnum(TableContact.values, 'contact'),
        pocket: f.optEnum(TablePocket.values, 'pocket'),
        repeat: f.optInt('repeat') ?? 1,
        fromGhostId: from == cue ? null : from,
        extras: {
          for (final e in s.entries)
            if (!_stepKeys.contains(e.key)) e.key: '${e.value}',
        },
      );
      f.touchAll();
      return step;
    }(),
];
