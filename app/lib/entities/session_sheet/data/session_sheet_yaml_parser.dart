import 'dart:math' show Point;

import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_initiation.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_source.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theme.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theory.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/player_figure_layout.dart';
import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:yaml/yaml.dart';

typedef _Json = Map<String, Object?>;

/// Lit le YAML d'une séance du catalogue (FORMAT des séances § 3) et construit
/// la [SessionSheet] du domaine.
///
/// Lecture stricte : une clé manquante, une clé inconnue, une valeur du mauvais
/// type ou hors de la liste fermée lève `InvariantViolation(invalidSheet)`,
/// dont `detail` nomme le chemin en cause. Les invariants du domaine sont
/// appliqués à la construction.
SessionSheet parseSessionSheet(String source) {
  final Object? root;
  try {
    root = _plain(loadYaml(source));
  } on YamlException catch (e) {
    throw InvariantViolation(
      InvariantCode.invalidSheet,
      'YAML invalide : ${e.message}',
    );
  }
  if (root is! _Json) _fail('racine', 'objet YAML attendu');
  return _sheet(_Obj(root, ''));
}

Never _fail(String where, String problem) =>
    throw InvariantViolation(InvariantCode.invalidSheet, '$where : $problem');

Object? _plain(Object? node) {
  if (node is Map) {
    return <String, Object?>{
      for (final e in node.entries) '${e.key}': _plain(e.value),
    };
  }
  if (node is List) return [for (final v in node) _plain(v)];
  return node;
}

String _snake(Enum e) =>
    e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// Objet YAML dont chaque clé lue est comptée : [done] refuse le reste.
class _Obj {
  _Obj(this._map, this._path);

  final _Json _map;
  final String _path;
  final _read = <String>{};

  String at(String key) => _path.isEmpty ? key : '$_path.$key';

  Never fail(String key, String problem) => _fail(at(key), problem);

  bool has(String key) => _map.containsKey(key);

  /// Valeur brute d'une clé obligatoire (peut valoir `null`).
  Object? raw(String key) {
    if (!_map.containsKey(key)) fail(key, 'clé obligatoire absente');
    _read.add(key);
    return _map[key];
  }

  Object? optionalRaw(String key) {
    _read.add(key);
    return _map[key];
  }

  String str(String key) {
    final v = raw(key);
    if (v is String && v.trim().isNotEmpty) return v;
    fail(key, 'texte non vide attendu, trouvé : $v');
  }

  String? nullableStr(String key) {
    final v = raw(key);
    if (v == null) return null;
    if (v is String && v.trim().isNotEmpty) return v;
    fail(key, 'texte ou null attendu, trouvé : $v');
  }

  /// Texte d'une valeur qui peut être écrite comme nombre (`label: 3`).
  String? looseStr(String key) {
    final v = optionalRaw(key);
    return v == null ? null : '$v';
  }

  int integer(String key) {
    final v = raw(key);
    if (v is int) return v;
    fail(key, 'entier attendu, trouvé : $v');
  }

  int? optionalInt(String key) {
    final v = optionalRaw(key);
    if (v == null) return null;
    if (v is int) return v;
    fail(key, 'entier attendu, trouvé : $v');
  }

  int? nullableInt(String key) {
    final v = raw(key);
    if (v == null) return null;
    if (v is int) return v;
    fail(key, 'entier ou null attendu, trouvé : $v');
  }

  bool boolean(String key) {
    final v = raw(key);
    if (v is bool) return v;
    fail(key, 'booléen attendu, trouvé : $v');
  }

  _Obj obj(String key) {
    final v = raw(key);
    if (v is _Json) return _Obj(v, at(key));
    fail(key, 'objet attendu, trouvé : $v');
  }

  _Obj? optionalObj(String key) {
    if (!has(key)) return null;
    return obj(key);
  }

  List<Object?> list(String key) {
    final v = raw(key);
    if (v is List) return v;
    fail(key, 'liste attendue, trouvé : $v');
  }

  List<Object?> optionalList(String key) {
    if (!has(key)) return const [];
    return list(key);
  }

  List<_Obj> objects(String key, {bool optional = false}) {
    if (optional && !has(key)) return const [];
    final items = list(key);
    return [
      for (final (i, v) in items.indexed)
        if (v is _Json)
          _Obj(v, '${at(key)}[$i]')
        else
          _fail('${at(key)}[$i]', 'objet attendu'),
    ];
  }

  List<String> strings(String key, {bool optional = false}) {
    if (optional && !has(key)) return const [];
    final items = list(key);
    return [
      for (final (i, v) in items.indexed)
        if (v is String && v.trim().isNotEmpty)
          v
        else
          _fail('${at(key)}[$i]', 'texte non vide attendu, trouvé : $v'),
    ];
  }

  E enumOf<E extends Enum>(List<E> values, String key) =>
      _enum(values, raw(key), at(key));

  E? optionalEnum<E extends Enum>(List<E> values, String key) {
    final v = optionalRaw(key);
    return v == null ? null : _enum(values, v, at(key));
  }

  Point<double> point(String key) => _point(raw(key), at(key));

  List<Point<double>> points(String key) {
    final items = list(key);
    return [for (final (i, v) in items.indexed) _point(v, '${at(key)}[$i]')];
  }

  /// Refuse toute clé que le modèle ne lit pas.
  void done() {
    final left = _map.keys.where((k) => !_read.contains(k)).toList();
    if (left.isNotEmpty) {
      _fail(
        _path.isEmpty ? 'racine' : _path,
        'clé inconnue : ${left.join(', ')}',
      );
    }
  }

  /// Clés non lues, rendues sous forme de texte (champs libres d'un tir).
  Map<String, String> remainder() {
    final rest = <String, String>{
      for (final e in _map.entries)
        if (!_read.contains(e.key)) e.key: '${e.value}',
    };
    _read.addAll(_map.keys);
    return rest;
  }
}

E _enum<E extends Enum>(List<E> values, Object? raw, String where) {
  for (final v in values) {
    if (_snake(v) == raw) return v;
  }
  _fail(where, 'valeur inconnue : $raw');
}

Point<double> _point(Object? raw, String where) {
  if (raw is List && raw.length == 2) {
    final x = raw[0];
    final y = raw[1];
    if (x is num && y is num) return Point(x.toDouble(), y.toDouble());
  }
  _fail(where, 'point [x, y] numérique attendu, trouvé : $raw');
}

// --- séance ------------------------------------------------------------

SessionSheet _sheet(_Obj o) {
  if (o.raw('version') != 1) o.fail('version', 'doit valoir 1');
  try {
    final sheet = SessionSheet(
      id: _sheetId(o.str('id'), o.at('id')),
      order: o.integer('order'),
      technique: o.str('technique'),
      part: o.integer('part'),
      title: o.str('title'),
      technicalSheets: _ints(o, 'technical_sheets'),
      previous: switch (o.nullableStr('previous')) {
        null => null,
        final v => _sheetId(v, o.at('previous')),
      },
      catalogueBlock: o.str('catalogue_block'),
      notion: o.str('notion'),
      theme: _theme(o.obj('theme')),
      recall: _recall(o.obj('recall')),
      theorySections: _theory(o.obj('theory')),
      initiation: [
        for (final i in o.objects('initiation', optional: true)) _initiation(i),
      ],
      illustrations: [
        for (final i in o.objects('illustrations')) _illustration(i),
      ],
      exercises: _exercises(o.obj('training')),
      game: _game(o.obj('game')),
      reviewPrompts: _review(o.obj('review')),
      sources: [for (final s in o.objects('sources')) _sourceRef(s)],
      uncertainties: o.strings('uncertainties', optional: true),
    );
    o.done();
    return sheet;
  } on InvariantViolation catch (e) {
    if (e.detail != null) rethrow;
    // Invariant du domaine (SheetId, ExerciseRef, ...) : on l'annote.
    throw InvariantViolation(InvariantCode.invalidSheet, e.code.name);
  }
}

List<int> _ints(_Obj o, String key) {
  final items = o.list(key);
  for (final (i, v) in items.indexed) {
    if (v is! int) _fail('${o.at(key)}[$i]', 'entier attendu, trouvé : $v');
  }
  return items.cast<int>();
}

SheetId _sheetId(String value, String where) {
  final id = SheetId.tryParse(value);
  return id ?? _fail(where, 'identifiant de séance mal formé : $value');
}

/// Sources permises pour un exercice d'entraînement et pour un jeu : un
/// contenu repris des PDF fédéraux ou une proposition (FORMAT § 3).
const Set<Provenance> _sourcedOrProposal = {Provenance.s, Provenance.prop};

Provenance _src(_Obj o, {Set<Provenance>? allowed}) {
  final value = o.raw('src');
  final source = switch (value) {
    'S' => Provenance.s,
    'FFB' => Provenance.ffb,
    'Web' => Provenance.web,
    'Prop' => Provenance.prop,
    _ => o.fail('src', 'S, FFB, Web ou Prop attendu, trouvé : $value'),
  };
  if (allowed != null && !allowed.contains(source)) {
    o.fail('src', 'valeur non permise ici : $value');
  }
  return source;
}

SheetTheme _theme(_Obj o) {
  final theme = SheetTheme(name: o.str('name'), pitch: o.str('pitch'));
  o.done();
  return theme;
}

SheetRecall _recall(_Obj o) {
  final question = o.obj('question');
  final ask = question.str('ask');
  final answer = question.str('answer');
  question.done();
  final reuse = o.optionalObj('reuse');
  SheetReuse? reused;
  if (reuse != null) {
    reused = SheetReuse(
      sheet: _sheetId(reuse.str('sheet'), reuse.at('sheet')),
      illustration: reuse.str('illustration'),
    );
    reuse.done();
  }
  final recall = SheetRecall(
    points: o.strings('points'),
    ask: ask,
    answer: answer,
    reuse: reused,
    src: _src(o),
  );
  o.done();
  return recall;
}

AudienceWeight _weight(_Obj o) {
  final weight = o.obj('weight');
  final children = weight.optionalInt('children');
  final adults = weight.optionalInt('adults');
  weight.done();
  try {
    return AudienceWeight(children: children, adults: adults);
  } on InvariantViolation {
    return o.fail('weight', 'poids entier >= 1 pour au moins un public');
  }
}

List<SheetTheorySection> _theory(_Obj o) {
  final sections = [for (final s in o.objects('sections')) _section(s)];
  o.done();
  return sections;
}

SheetTheorySection _section(_Obj o) {
  final section = SheetTheorySection(
    id: o.str('id'),
    title: o.str('title'),
    weight: _weight(o),
    body: o.strings('body'),
    adultExtra: o.strings('adult_extra', optional: true),
    keyPoint: o.str('key_point'),
    demo: o.nullableStr('demo'),
    illustrationIds: o.strings('illustrations'),
    src: _src(o),
  );
  o.done();
  return section;
}

SheetInitiation _initiation(_Obj o) {
  final item = SheetInitiation(
    id: o.str('id'),
    initiationSheet: o.integer('initiation_sheet'),
    title: o.str('title'),
    weight: _weight(o),
    setup: o.str('setup'),
    goal: o.str('goal'),
    expected: o.str('expected'),
    scoring: _scoring(o.obj('scoring')),
    illustrationId: o.nullableStr('illustration'),
    src: _src(o),
  );
  o.done();
  return item;
}

Scoring _scoring(_Obj o) {
  final mode = o.raw('mode');
  final scoring = switch (mode) {
    'counter' => () {
      final of = o.integer('of');
      if (of < 1) o.fail('of', 'entier >= 1 attendu');
      return Scoring.counter(of: of);
    }(),
    'checklist' => () {
      final criteria = o.strings('criteria');
      if (criteria.isEmpty) o.fail('criteria', 'liste non vide attendue');
      return Scoring.checklist(criteria: criteria);
    }(),
    _ => o.fail('mode', 'counter ou checklist attendu, trouvé : $mode'),
  };
  o.done();
  return scoring;
}

List<SheetExercise> _exercises(_Obj o) {
  final exercises = [for (final e in o.objects('exercises')) _exercise(e)];
  o.done();
  return exercises;
}

SheetExercise _exercise(_Obj o) {
  final ref = o.obj('ref');
  final block = ref.str('block');
  final number = ref.integer('n');
  ref.done();
  final ExerciseRef exerciseRef;
  try {
    exerciseRef = ExerciseRef(blockId: block, number: number);
  } on InvariantViolation {
    return o.fail('ref', "référence d'exercice invalide : $block $number");
  }
  final playful = o.obj('playful');
  final sheetPlayful = SheetPlayful(
    hook: playful.str('hook'),
    challenge: playful.str('challenge'),
  );
  playful.done();
  final exercise = SheetExercise(
    id: o.str('id'),
    ref: exerciseRef,
    diagramId: o.str('diagram'),
    title: o.str('title'),
    weight: _weight(o),
    setup: o.str('setup'),
    instruction: o.str('instruction'),
    expected: o.str('expected'),
    mistakes: [
      for (final m in o.objects('mistakes'))
        () {
          final mistake = SheetMistake(
            symptom: m.str('symptom'),
            fix: m.str('fix'),
          );
          m.done();
          return mistake;
        }(),
    ],
    playful: sheetPlayful,
    passes: o.integer('passes'),
    src: _src(o, allowed: _sourcedOrProposal),
  );
  o.done();
  return exercise;
}

SheetGame _game(_Obj o) {
  final linkObj = o.optionalObj('link_previous');
  SheetLink? link;
  if (linkObj != null) {
    link = SheetLink(
      notionOf: _sheetId(linkObj.str('notion_of'), linkObj.at('notion_of')),
      rule: linkObj.str('rule'),
      note: linkObj.str('note'),
    );
    linkObj.done();
  }
  final adaptation = o.obj('adaptation');
  final sheetAdaptation = SheetAdaptation(
    children: adaptation.nullableStr('children'),
    adults: adaptation.nullableStr('adults'),
  );
  adaptation.done();
  final game = SheetGame(
    title: o.str('title'),
    sourceGame: o.nullableInt('source_game'),
    adapted: o.boolean('adapted'),
    players: o.str('players'),
    materials: o.nullableStr('materials'),
    setupIllustrationId: o.nullableStr('setup_illustration'),
    rules: o.strings('rules'),
    scoring: o.str('scoring'),
    end: o.str('end'),
    playfulVariant: o.str('playful_variant'),
    link: link,
    weight: _weight(o),
    adaptation: sheetAdaptation,
    src: _src(o, allowed: _sourcedOrProposal),
  );
  o.done();
  return game;
}

List<String> _review(_Obj o) {
  final prompts = o.strings('prompts');
  o.done();
  return prompts;
}

SheetSourceRef _sourceRef(_Obj o) {
  final rank = o.raw('rank');
  final source = switch (rank) {
    'S' => Provenance.s,
    'FFB' => Provenance.ffb,
    'Web' => Provenance.web,
    _ => o.fail('rank', 'S, FFB ou Web attendu, trouvé : $rank'),
  };
  final ref = SheetSourceRef(
    rank: source,
    file: o.str('file'),
    page: o.optionalInt('page'),
    note: o.str('note'),
  );
  o.done();
  return ref;
}

// --- illustrations -------------------------------------------------------

Illustration _illustration(_Obj o) {
  final id = o.str('id');
  final caption = o.str('caption');
  final alt = o.str('alt');
  final type = o.raw('type');
  final illustration = switch (type) {
    'diagram_ref' => Illustration.diagramRef(
      id: id,
      caption: caption,
      alt: alt,
      diagramId: o.str('diagram'),
    ),
    'table' => _table(o, id, caption, alt),
    'contact' => Illustration.contact(
      id: id,
      caption: caption,
      alt: alt,
      fraction: o.enumOf(ContactFraction.values, 'fraction'),
      tipPoint: o.enumOf(TipPoint.values, 'tip_point'),
    ),
    'contact_strip' => Illustration.contactStrip(
      id: id,
      caption: caption,
      alt: alt,
      fractions: [
        for (final (i, v) in o.list('fractions').indexed)
          _enum(ContactFraction.values, v, '${o.at('fractions')}[$i]'),
      ],
      highlight: o.optionalEnum(ContactFraction.values, 'highlight'),
    ),
    'ghost_aim' => Illustration.ghostAim(
      id: id,
      caption: caption,
      alt: alt,
      cue: o.point('cue'),
      object: o.point('object'),
      pocket: o.enumOf(TablePocket.values, 'pocket'),
      fraction: o.enumOf(ContactFraction.values, 'fraction'),
    ),
    'cue_ball_target' => Illustration.cueBallTarget(
      id: id,
      caption: caption,
      alt: alt,
      tipPoint: o.enumOf(TipPoint.values, 'tip_point'),
      compare: [
        for (final (i, v) in o.optionalList('compare').indexed)
          _enum(TipPoint.values, v, '${o.at('compare')}[$i]'),
      ],
      cueHeight: o.optionalEnum(CueHeight.values, 'cue_height'),
    ),
    'ball_size' => Illustration.ballSize(id: id, caption: caption, alt: alt),
    'player_figure' => _playerFigure(o, id, caption, alt),
    'power_ratio' => _powerRatio(o, id, caption, alt),
    'angle' => Illustration.angle(
      id: id,
      caption: caption,
      alt: alt,
      kind: o.enumOf(AngleKind.values, 'kind'),
      vertex: o.point('vertex'),
      rays: o.points('rays'),
    ),
    'pdf_ref' => Illustration.pdfRef(
      id: id,
      caption: caption,
      alt: alt,
      file: o.str('file'),
      page: o.integer('page'),
    ),
    _ => o.fail('type', 'type hors de la liste fermée : $type'),
  };
  o.done();
  return illustration;
}

Illustration _playerFigure(_Obj o, String id, String caption, String alt) {
  final view = o.enumOf(PlayerView.values, 'view');
  final focus = [
    for (final (i, v) in o.optionalList('focus').indexed)
      _enum(PlayerMark.values, v, '${o.at('focus')}[$i]'),
  ];
  if (o.has('focus') && focus.isEmpty) {
    o.fail('focus', 'au moins un repère attendu');
  }
  if (focus.toSet().length != focus.length) {
    o.fail('focus', 'repère en double');
  }
  final headCase = o.optionalEnum(HeadCase.values, 'head_case');
  if (headCase != null && view == PlayerView.side) {
    o.fail('head_case', 'la place de la tête se lit de dessus (view: top)');
  }
  return Illustration.playerFigure(
    id: id,
    caption: caption,
    alt: alt,
    view: view,
    focus: focus.isEmpty ? PlayerMark.values : focus,
    leadEye: o.optionalEnum(LeadEye.values, 'lead_eye'),
    headCase: headCase,
    bridge: o.optionalEnum(CueBridge.values, 'bridge') ?? CueBridge.frame,
  );
}

Illustration _powerRatio(_Obj o, String id, String caption, String alt) {
  final points = [
    for (final p in o.objects('points', optional: true))
      () {
        final point = PowerPoint(
          amplitude: p.enumOf(AmplitudeLevel.values, 'amplitude'),
          speed: p.enumOf(SpeedLevel.values, 'speed'),
          label: p.looseStr('label'),
        );
        p.done();
        return point;
      }(),
  ];
  final highlight = o.optionalInt('highlight');
  if (highlight != null && (highlight < 0 || highlight >= points.length)) {
    o.fail(
      'highlight',
      "indice d'un exemple de points attendu (0 à ${points.length - 1})",
    );
  }
  return Illustration.powerRatio(
    id: id,
    caption: caption,
    alt: alt,
    points: points,
    highlight: highlight,
    distanceLabel: o.looseStr('distance_label'),
  );
}

Illustration _table(_Obj o, String id, String caption, String alt) {
  final balls = [
    for (final b in o.objects('balls'))
      () {
        final ball = IllustrationBall(
          id: b.str('id'),
          color: b.enumOf(IllustrationBallColor.values, 'color'),
          at: b.point('at'),
          role: b.optionalEnum(IllustrationBallRole.values, 'role'),
          label: b.looseStr('label'),
          order: b.optionalInt('order'),
        );
        b.done();
        return ball;
      }(),
  ];
  final ghosts = [
    for (final g in o.objects('ghosts', optional: true))
      () {
        final ghost = IllustrationGhost(
          id: g.str('id'),
          at: g.point('at'),
          role: g.enumOf(IllustrationGhostRole.values, 'role'),
          forBallId: g.looseStr('for'),
          label: g.looseStr('label'),
        );
        g.done();
        return ghost;
      }(),
  ];
  final arrows = [
    for (final a in o.objects('arrows', optional: true))
      () {
        final arrow = IllustrationArrow(
          id: a.str('id'),
          kind: a.enumOf(IllustrationArrowKind.values, 'kind'),
          path: a.points('path'),
          ballId: a.looseStr('ball'),
          bounces: [
            for (final (i, v) in a.optionalList('bounces').indexed)
              _enum(IllustrationBand.values, v, '${a.at('bounces')}[$i]'),
          ],
          pocket: a.optionalEnum(TablePocket.values, 'to'),
          label: a.looseStr('label'),
          note: a.looseStr('note'),
        );
        a.done();
        return arrow;
      }(),
  ];
  final zones = [
    for (final z in o.objects('zones', optional: true))
      () {
        if (z.raw('shape') != 'rect') {
          z.fail('shape', 'seuls les rectangles sont représentés');
        }
        final zone = IllustrationZone(
          id: z.str('id'),
          from: z.point('from'),
          to: z.point('to'),
          label: z.looseStr('label'),
        );
        z.done();
        return zone;
      }(),
  ];
  final steps = [
    for (final (i, s) in o.objects('sequence', optional: true).indexed)
      _step(s, i),
  ];
  return Illustration.table(
    id: id,
    caption: caption,
    alt: alt,
    balls: balls,
    ghosts: ghosts,
    arrows: arrows,
    zones: zones,
    steps: steps,
  );
}

IllustrationStep _step(_Obj s, int index) {
  if (s.raw('step') != index + 1) {
    s.fail('step', 'attendu ${index + 1}, trouvé : ${s.raw('step')}');
  }
  final cue = s.str('cue');
  final contact = s.optionalRaw('contact');
  final from = s.looseStr('from');
  final step = IllustrationStep(
    cueId: cue,
    hitId: s.looseStr('hit'),
    contact: contact == null || contact == 'none'
        ? null
        : _enum(ContactFraction.values, contact, s.at('contact')),
    pocket: s.optionalEnum(TablePocket.values, 'pocket'),
    repeat: s.optionalInt('repeat') ?? 1,
    fromGhostId: from == cue ? null : from,
    extras: s.remainder(),
  );
  return step;
}
