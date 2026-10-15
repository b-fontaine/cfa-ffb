// Règles V1 à V24 appliquées à une séance (FORMAT.md § 7). V12 (minutage)
// est vérifiée par le test de contrat Dart ; V17 (cohérence géométrique de
// ghost_aim : |d - d_nominal| <= 0,07 s, avec s = r_c + r_o) l'est ici et par
// le test de contrat.
import 'dart:convert';
import 'dart:math' show Point;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/ghost_ball_geometry.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:yaml/yaml.dart';

import '../diagrammes/model.dart';
import '../diagrammes/validator.dart';
import 'catalogue.dart';
import 'context.dart';

const _audiences = ['children', 'adults'];
const _srcValues = {'S', 'FFB', 'Web', 'Prop'};
const _sourceRanks = {'S', 'FFB', 'Web'};
const _illustrationTypes = {
  'diagram_ref',
  'table',
  'contact',
  'contact_strip',
  'ghost_aim',
  'cue_ball_target',
  'player_figure',
  'ball_size',
  'contact_height',
  'power_ratio',
  'angle',
  'pdf_ref',
};
const _fractions = {'full', 'three_quarter', 'half', 'quarter', 'thin'};
const _tipPoints = {
  'center',
  'top',
  'bottom',
  'left',
  'right',
  'top_left',
  'top_right',
  'bottom_left',
  'bottom_right',
};
const _cueHeights = {'high', 'level', 'low'};
const _playerViews = {'side', 'top', 'both'};
const _playerMarks = {
  'feet',
  'legs_and_hips',
  'head',
  'back_forearm',
  'bridge_hand',
  'cue',
};
const _leadEyes = {'left', 'right'};
const _headCases = {
  'right_eye_over_cue',
  'cue_between_eyes',
  'left_eye_over_cue',
};
const _bridges = {'frame', 'surface'};
const _handedness = {'right', 'left'};
const _tipOffsets = {'slight', 'half'};
const _amplitudes = {'short', 'medium', 'long'};
const _speeds = {'slow', 'medium', 'fast'};
const _powerPointKeys = {'amplitude', 'speed', 'label'};

/// Nombre maximal d'exemples d'un `power_ratio` (charge pour des débutants :
/// les deux extrêmes de la fiche n° 2).
const _maxPowerPoints = 2;
const _angleKinds = {'bounce', 'natural_rejection', 'right_angle'};
const _forbiddenIllustrationKeys = {'photo', 'image', 'path', 'url', 'asset'};

final _slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
final _imagePath = RegExp(
  r'\.(png|jpe?g|gif|webp|bmp|svg|heic)(?![a-z0-9])',
  caseSensitive: false,
);
final _rate = RegExp(r'\d+\s*/\s*\d+');
final _ballCount = RegExp(
  r'\b(\d+|une?|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\s+billes?\b',
  caseSensitive: false,
);

class _Keys {
  const _Keys(this.required, [this.optional = const {}]);
  final Set<String> required;
  final Set<String> optional;
}

const _rootKeys = _Keys(
  {
    'version',
    'id',
    'order',
    'technique',
    'part',
    'title',
    'technical_sheets',
    'previous',
    'catalogue_block',
    'notion',
    'theme',
    'recall',
    'theory',
    'illustrations',
    'training',
    'game',
    'review',
    'sources',
  },
  {'initiation', 'uncertainties'},
);
const _themeKeys = _Keys({'name', 'pitch'});
const _recallKeys = _Keys({'points', 'question', 'src'}, {'reuse'});
const _questionKeys = _Keys({'ask', 'answer'});
const _reuseKeys = _Keys({'sheet', 'illustration'});
const _theoryKeys = _Keys({'sections'});
const _sectionKeys = _Keys(
  {
    'id',
    'title',
    'weight',
    'body',
    'key_point',
    'demo',
    'illustrations',
    'src',
  },
  {'adult_extra'},
);
const _initiationKeys = _Keys({
  'id',
  'initiation_sheet',
  'title',
  'weight',
  'setup',
  'goal',
  'expected',
  'scoring',
  'illustration',
  'src',
});
const _trainingKeys = _Keys({'exercises'}, {'recall_slot'});
const _recallSlotKeys = _Keys({'weight', 'passes'});
const _exerciseKeys = _Keys(
  {
    'id',
    'diagram',
    'title',
    'weight',
    'setup',
    'instruction',
    'expected',
    'mistakes',
    'passes',
    'src',
  },
  // `ref` (V4) et `playful` (V20) : leur absence est signalée par leur règle.
  {'ref', 'playful'},
);
const _refKeys = _Keys({'block', 'n'});
const _mistakeKeys = _Keys({'symptom', 'fix'});
const _playfulKeys = _Keys({'hook', 'challenge'});
const _gameKeys = _Keys(
  {
    'title',
    'source_game',
    'adapted',
    'players',
    'materials',
    'setup_illustration',
    'rules',
    'scoring',
    'end',
    'playful_variant',
    'weight',
    'adaptation',
    'src',
  },
  {'link_previous'},
);
const _linkKeys = _Keys({'notion_of', 'rule', 'note'});
const _adaptationKeys = _Keys({'children', 'adults'});
const _reviewKeys = _Keys({'prompts'});
const _sourceKeys = _Keys({'rank', 'file', 'note'}, {'page'});

const _illustrationParams = <String, _Keys>{
  'diagram_ref': _Keys({'diagram'}),
  'table': _Keys({'balls'}, {'ghosts', 'arrows', 'zones', 'sequence'}),
  'contact': _Keys({'fraction', 'tip_point'}, {'offset', 'paths'}),
  'contact_strip': _Keys({'fractions'}, {'highlight'}),
  'ghost_aim': _Keys({'cue', 'object', 'pocket', 'fraction'}),
  'cue_ball_target': _Keys({'tip_point'}, {'compare', 'cue_height', 'offset'}),
  'player_figure': _Keys(
    {'view'},
    {'focus', 'lead_eye', 'head_case', 'bridge', 'handedness'},
  ),
  'ball_size': _Keys({}),
  'contact_height': _Keys({}),
  'power_ratio': _Keys({}, {'points', 'highlight', 'distance_label'}),
  'angle': _Keys({'kind', 'vertex', 'rays'}),
  'pdf_ref': _Keys({'file', 'page'}),
};

/// Valide le texte YAML d'une séance. [fileName] est le nom du fichier
/// (`NN-<id>.yaml`) ; [siblings] donne les autres séances connues, par `id`,
/// pour les contrôles croisés (V7 `recall.reuse`).
List<String> validateSession(
  String text, {
  required String fileName,
  required FichesContext context,
  Map<String, Json> siblings = const {},
}) {
  final Object? doc;
  try {
    doc = toPlain(loadYaml(text));
  } on YamlException catch (e) {
    return ['V1 : racine : YAML invalide : ${e.message}'];
  }
  if (doc is! Map<String, Object?>) {
    return ['V1 : racine : objet YAML attendu'];
  }
  final session = _Session(doc, fileName, context, siblings)..run();
  return session.errors;
}

int _words(String text) =>
    text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

Iterable<String> _strings(Object? node) sync* {
  if (node is String) {
    yield node;
  } else if (node is Map) {
    for (final v in node.values) {
      yield* _strings(v);
    }
  } else if (node is List) {
    for (final v in node) {
      yield* _strings(v);
    }
  }
}

class _Session {
  _Session(this.doc, this.fileName, this.ctx, this.siblings);

  final Json doc;
  final String fileName;
  final FichesContext ctx;
  final Map<String, Json> siblings;
  final errors = <String>[];

  Structure get _structure => ctx.structure;

  SessionSlot? _slot;
  TechniqueSpec? _spec;
  CatalogueBlock? _block;
  int? _order;
  String? _previous;
  bool _hasPreviousKey = false;
  final _illustrationIds = <String>{};

  /// Poids affichés par public : audience -> nombre d'éléments.
  final Map<String, int> _sections = {for (final a in _audiences) a: 0};
  final Map<String, Set<String>> _exercises = {
    for (final a in _audiences) a: <String>{},
  };

  void _e(String rule, String path, String message) =>
      errors.add('$rule : $path : $message');

  // --- accès typés -------------------------------------------------------

  Json? _map(Object? v, String path, {String rule = 'V1'}) {
    if (v is Map<String, Object?>) return v;
    _e(rule, path, 'objet attendu');
    return null;
  }

  List<Object?>? _list(Object? v, String path, {String rule = 'V1'}) {
    if (v is List) return v;
    _e(rule, path, 'liste attendue');
    return null;
  }

  String? _text(Object? v, String path, {String rule = 'V1'}) {
    if (v is String && v.trim().isNotEmpty) return v;
    _e(rule, path, 'texte non vide attendu');
    return null;
  }

  void _keys(Json o, String path, _Keys k, {Set<String> skip = const {}}) {
    String at(String key) => path.isEmpty ? key : '$path.$key';
    for (final r in k.required) {
      if (!o.containsKey(r)) _e('V1', at(r), 'clé obligatoire absente');
    }
    for (final key in o.keys) {
      if (!k.required.contains(key) &&
          !k.optional.contains(key) &&
          !skip.contains(key)) {
        _e('V1', at(key), 'clé inconnue');
      }
    }
  }

  // --- déroulé -----------------------------------------------------------

  void run() {
    _keys(doc, '', _rootKeys);
    _identity();
    _notion();
    _theme();
    _recall();
    _theory();
    _initiation();
    _illustrations();
    _training();
    _game();
    _review();
    _sourcesRule();
    _referencesToIllustrations();
    _orphanIllustrations();
    _weightsMinimum();
    _imagePaths();
    _officialWord();
    _sourcesPath();
  }

  // --- V1 (version) / V2 / V3 / V4 (bloc) ---------------------------------

  void _identity() {
    if (doc['version'] != 1) _e('V1', 'version', 'doit valoir 1');
    final id = doc['id'];
    final technique = doc['technique'];
    final part = doc['part'];
    final order = doc['order'];
    if (order is int) {
      _order = order;
    } else {
      _e('V1', 'order', 'entier attendu');
    }
    if (id is! String || !_slug.hasMatch(id)) {
      _e('V2', 'id', 'doit être un slug (a-z, 0-9, tiret) : $id');
    }
    if (technique is! String || techniqueSpec(technique) == null) {
      _e('V2', 'technique', 'technique inconnue : $technique');
    } else {
      _spec = techniqueSpec(technique);
    }
    if (part is! int) _e('V1', 'part', 'entier attendu');
    if (technique is String && part is int && _spec != null) {
      _slot = _structure.slotFor(technique, part);
      final parts = _structure.partsByTechnique[technique];
      if (_slot == null) {
        _e(
          'V2',
          'part',
          'partie $part inexistante : $technique a ${parts ?? '?'} partie(s)',
        );
      } else {
        if (id != '$technique-$part') {
          _e('V2', 'id', 'attendu ${_slot!.id}, trouvé $id');
        }
        if (order is int && order != _slot!.order) {
          _e('V2', 'order', 'attendu ${_slot!.order}, trouvé $order');
        }
      }
    }
    _fileName(id);
    _previousRule();
    _blockRule();
    _techniqueSheets();
  }

  void _fileName(Object? id) {
    final m = RegExp(r'^(\d{2})-(.+)\.yaml$').firstMatch(fileName);
    if (m == null) {
      _e('V2', 'fichier', 'nom attendu NN-<id>.yaml : $fileName');
      return;
    }
    final order = _slot?.order ?? _order;
    if (order != null && int.parse(m.group(1)!) != order) {
      _e(
        'V2',
        'fichier',
        'préfixe ${order.toString().padLeft(2, '0')} attendu : $fileName',
      );
    }
    if (id is String && m.group(2) != id) {
      _e('V2', 'fichier', "le nom doit finir par l'id « $id » : $fileName");
    }
  }

  void _previousRule() {
    _hasPreviousKey = doc.containsKey('previous');
    final prev = doc['previous'];
    if (prev != null && prev is! String) {
      _e('V3', 'previous', 'identifiant de séance ou null attendu');
      return;
    }
    _previous = prev as String?;
    final slot = _slot;
    if (slot == null) return;
    if (slot.order == 1) {
      if (prev != null) _e('V3', 'previous', 'doit être null pour order 1');
    } else if (prev != slot.previous) {
      _e('V3', 'previous', 'attendu ${slot.previous}, trouvé $prev');
    }
    // V22 : une partie k > 1 suit la partie k - 1 de la même technique.
    if (slot.part > 1 && prev != '${slot.technique}-${slot.part - 1}') {
      _e(
        'V22',
        'previous',
        'la partie ${slot.part} suit ${slot.technique}-${slot.part - 1}',
      );
    }
  }

  void _blockRule() {
    final block = doc['catalogue_block'];
    final spec = _spec;
    if (block == null) {
      _e('V4', 'catalogue_block', 'ne doit pas être nul');
      return;
    }
    if (block is! String) {
      _e('V4', 'catalogue_block', 'identifiant de bloc attendu');
      return;
    }
    if (spec != null && block != spec.blockId) {
      _e('V4', 'catalogue_block', 'attendu ${spec.blockId}, trouvé $block');
    }
    _block = _structure.blocks[spec?.blockId ?? block];
    if (_block == null) {
      _e('V4', 'catalogue_block', 'bloc $block absent du catalogue');
    }
  }

  void _techniqueSheets() {
    final sheets = doc['technical_sheets'];
    final spec = _spec;
    if (sheets is! List || sheets.any((e) => e is! int)) {
      _e('V1', 'technical_sheets', "liste d'entiers attendue");
      return;
    }
    if (spec != null && sheets.join(',') != spec.technicalSheets.join(',')) {
      _e(
        'V15',
        'technical_sheets',
        'attendu ${spec.technicalSheets}, trouvé $sheets',
      );
    }
  }

  // --- V15 notion ----------------------------------------------------------

  void _notion() {
    final notion = doc['notion'];
    if (notion is! String || notion.trim().isEmpty) {
      _e('V1', 'notion', 'texte non vide attendu');
      return;
    }
    final t = notion.trim();
    if (t.contains(';') || RegExp(r'[.!?]\s').hasMatch(t)) {
      _e('V15', 'notion', 'doit tenir en une seule phrase');
    }
    if (_words(t) > 25) {
      _e('V15', 'notion', 'plus de 25 mots (${_words(t)})');
    }
  }

  // --- V20 thème -----------------------------------------------------------

  void _theme() {
    final raw = doc['theme'];
    if (raw is! Map<String, Object?>) {
      _e('V20', 'theme', 'objet obligatoire (name, pitch)');
      return;
    }
    _keys(raw, 'theme', _themeKeys);
    final name = raw['name'];
    if (name is! String || name.trim().isEmpty) {
      _e('V20', 'theme.name', 'texte non vide attendu');
    } else if (_words(name) < 2 || _words(name) > 4) {
      _e('V20', 'theme.name', '2 à 4 mots attendus (${_words(name)})');
    }
    final pitch = raw['pitch'];
    if (pitch is! String || pitch.trim().isEmpty) {
      _e('V20', 'theme.pitch', 'texte non vide attendu');
    }
  }

  // --- rappel (V13, V22, V7) ----------------------------------------------

  void _recall() {
    final recall = _map(doc['recall'], 'recall');
    if (recall == null) return;
    _keys(recall, 'recall', _recallKeys);
    final points = _list(recall['points'], 'recall.points');
    if (points != null) {
      if (points.length < 2 || points.length > 4) {
        _e('V1', 'recall.points', '2 à 4 puces attendues');
      }
      for (var i = 0; i < points.length; i++) {
        _text(points[i], 'recall.points[$i]');
      }
    }
    final q = _map(recall['question'], 'recall.question');
    if (q != null) {
      _keys(q, 'recall.question', _questionKeys);
      _text(q['ask'], 'recall.question.ask');
      _text(q['answer'], 'recall.question.answer');
    }
    _src(recall['src'], 'recall.src');
    if (!recall.containsKey('reuse')) return;
    final reuse = _map(recall['reuse'], 'recall.reuse');
    if (reuse == null) return;
    _keys(reuse, 'recall.reuse', _reuseKeys);
    final order = _slot?.order ?? _order;
    if (order == 1) {
      _e(
        'V22',
        'recall.reuse',
        'interdit pour order 1 (aucune séance précédente)',
      );
      return;
    }
    final sheet = reuse['sheet'];
    final illustration = reuse['illustration'];
    if (_previous != null && sheet != _previous) {
      _e('V22', 'recall.reuse.sheet', 'doit être previous ($_previous)');
    }
    final other = sheet is String ? siblings[sheet] : null;
    if (other != null && illustration is String) {
      final ids = [
        for (final i in (other['illustrations'] as List?) ?? const <Object?>[])
          if (i is Map) i['id'],
      ];
      if (!ids.contains(illustration)) {
        _e(
          'V7',
          'recall.reuse.illustration',
          'illustration « $illustration » absente de $sheet',
        );
      }
    }
  }

  // --- théorie (V11, V13, V16) ---------------------------------------------

  void _theory() {
    final theory = _map(doc['theory'], 'theory');
    if (theory == null) return;
    _keys(theory, 'theory', _theoryKeys);
    final sections = _list(theory['sections'], 'theory.sections');
    if (sections == null) return;
    final ids = <String>{};
    for (var i = 0; i < sections.length; i++) {
      final path = 'theory.sections[$i]';
      final s = _map(sections[i], path);
      if (s == null) continue;
      _keys(s, path, _sectionKeys);
      _localId(s['id'], '$path.id', ids);
      _text(s['title'], '$path.title');
      final weights = _weights(s['weight'], '$path.weight');
      for (final a in weights.keys) {
        _sections[a] = _sections[a]! + 1;
      }
      final body = _list(s['body'], '$path.body');
      final keyPoint = _text(s['key_point'], '$path.key_point');
      if (body != null) {
        for (var j = 0; j < body.length; j++) {
          final line = _text(body[j], '$path.body[$j]');
          if (line != null &&
              weights.containsKey('children') &&
              _words(line) > 60) {
            _e('V16', '$path.body[$j]', '${_words(line)} mots (max 60)');
          }
        }
      }
      if (keyPoint != null &&
          weights.containsKey('children') &&
          _words(keyPoint) > 20) {
        _e('V16', '$path.key_point', '${_words(keyPoint)} mots (max 20)');
      }
      if (s.containsKey('adult_extra')) {
        final extra = _list(s['adult_extra'], '$path.adult_extra');
        if (extra != null) {
          for (var j = 0; j < extra.length; j++) {
            _text(extra[j], '$path.adult_extra[$j]');
          }
        }
      }
      final demo = s['demo'];
      if (demo != null && demo is! String) {
        _e('V1', '$path.demo', 'texte ou null attendu');
      }
      final ill = _list(s['illustrations'], '$path.illustrations');
      if (ill != null) {
        for (var j = 0; j < ill.length; j++) {
          _citedIllustrations.add(('$path.illustrations[$j]', ill[j]));
        }
      }
      _src(s['src'], '$path.src');
    }
  }

  /// Illustrations citées (chemin, identifiant), résolues en fin de passe.
  final _citedIllustrations = <(String, Object?)>[];

  // --- initiation (V9, V13, V21) -------------------------------------------

  void _initiation() {
    if (!doc.containsKey('initiation')) return;
    final items = _list(doc['initiation'], 'initiation');
    if (items == null) return;
    final ids = <String>{};
    for (var i = 0; i < items.length; i++) {
      final path = 'initiation[$i]';
      final it = _map(items[i], path);
      if (it == null) continue;
      _keys(it, path, _initiationKeys);
      _localId(it['id'], '$path.id', ids);
      _weights(it['weight'], '$path.weight');
      for (final f in ['title', 'setup', 'goal', 'expected']) {
        _text(it[f], '$path.$f');
      }
      _sheetRule(it['initiation_sheet'], '$path.initiation_sheet');
      _scoring(it['scoring'], '$path.scoring');
      final ill = it['illustration'];
      if (ill != null) {
        _citedIllustrations.add(('$path.illustration', ill));
      }
      _src(it['src'], '$path.src');
    }
  }

  void _sheetRule(Object? sheet, String path) {
    if (sheet is! int) {
      _e('V21', path, "numéro de fiche d'initiation attendu");
      return;
    }
    if (!ctx.initiationSheets.contains(sheet)) {
      _e('V21', path, "fiche d'initiation $sheet absente de initiation.md");
      return;
    }
    final spec = _spec;
    if (spec != null && !spec.initiationSheets.contains(sheet)) {
      _e(
        'V21',
        path,
        "la fiche $sheet n'appartient pas à la technique ${spec.slug} "
            '(fiches ${spec.initiationSheets})',
      );
    }
  }

  void _scoring(Object? raw, String path) {
    final s = _map(raw, path, rule: 'V9');
    if (s == null) return;
    switch (s['mode']) {
      case 'counter':
        _keys(s, path, const _Keys({'mode', 'of'}));
        final of = s['of'];
        if (of is! int || of < 1) {
          _e('V9', '$path.of', 'entier >= 1 attendu');
        }
      case 'checklist':
        _keys(s, path, const _Keys({'mode', 'criteria'}));
        final c = s['criteria'];
        if (c is! List ||
            c.isEmpty ||
            c.any((e) => e is! String || e.trim().isEmpty)) {
          _e('V9', '$path.criteria', 'liste non vide de critères attendue');
        }
      default:
        _e('V9', '$path.mode', 'counter ou checklist attendu : ${s['mode']}');
    }
  }

  // --- illustrations (V7, V8, V17) -----------------------------------------

  void _illustrations() {
    final items = _list(doc['illustrations'], 'illustrations');
    if (items == null) return;
    for (var i = 0; i < items.length; i++) {
      final path = 'illustrations[$i]';
      final ill = _map(items[i], path, rule: 'V7');
      if (ill == null) continue;
      _illustration(ill, path);
    }
  }

  void _illustration(Json ill, String path) {
    final id = ill['id'];
    if (id is! String || !_slug.hasMatch(id)) {
      _e('V7', '$path.id', 'slug attendu : $id');
    } else if (!_illustrationIds.add(id)) {
      _e('V7', '$path.id', 'identifiant en double : $id');
    }
    for (final key in _forbiddenIllustrationKeys) {
      if (ill.containsKey(key)) {
        _e(
          'V8',
          '$path.$key',
          'clé interdite (illustrations générées uniquement)',
        );
      }
    }
    for (final f in ['caption', 'alt']) {
      final v = ill[f];
      if (v is! String || v.trim().isEmpty) {
        _e('V7', '$path.$f', 'texte non vide obligatoire');
      }
    }
    final type = ill['type'];
    if (type is! String || !_illustrationTypes.contains(type)) {
      _e('V7', '$path.type', 'type hors de la liste fermée : $type');
      return;
    }
    final params = _illustrationParams[type]!;
    final common = {'id', 'type', 'caption', 'alt'};
    for (final r in params.required) {
      if (!ill.containsKey(r)) {
        _e('V7', '$path.$r', 'paramètre de $type absent');
      }
    }
    for (final key in ill.keys) {
      if (!common.contains(key) &&
          !params.required.contains(key) &&
          !params.optional.contains(key) &&
          !_forbiddenIllustrationKeys.contains(key)) {
        _e('V1', '$path.$key', 'clé inconnue pour le type $type');
      }
    }
    switch (type) {
      case 'diagram_ref':
        final ref = ill['diagram'];
        if (ref is! String || !ctx.diagrams.containsKey(ref)) {
          _e('V6', '$path.diagram', 'diagramme inconnu : $ref');
        }
      case 'table':
        _tableIllustration(ill, path);
      case 'contact':
        _tipOffset(ill, path);
        _enum(ill['fraction'], _fractions, '$path.fraction');
        _enum(ill['tip_point'], _tipPoints, '$path.tip_point');
      case 'contact_strip':
        final f = ill['fractions'];
        if (f is! List || f.isEmpty) {
          _e('V7', '$path.fractions', 'liste non vide attendue');
        } else {
          for (final e in f) {
            _enum(e, _fractions, '$path.fractions');
          }
        }
        if (ill['highlight'] != null) {
          _enum(ill['highlight'], _fractions, '$path.highlight');
        }
      case 'ghost_aim':
        _ghostAim(ill, path);
      case 'cue_ball_target':
        _cueBallTarget(ill, path);
      case 'player_figure':
        _playerFigure(ill, path);
      case 'ball_size':
      case 'contact_height':
        break;
      case 'power_ratio':
        _powerRatio(ill, path);
      case 'angle':
        _enum(ill['kind'], _angleKinds, '$path.kind');
        _point(ill['vertex'], '$path.vertex', 'V7');
        final rays = ill['rays'];
        if (rays is! List || rays.isEmpty) {
          _e('V7', '$path.rays', 'liste non vide de points attendue');
        } else {
          for (var i = 0; i < rays.length; i++) {
            _point(rays[i], '$path.rays[$i]', 'V7');
          }
        }
      case 'pdf_ref':
        _text(ill['file'], '$path.file', rule: 'V7');
        final page = ill['page'];
        if (page is! int || page < 1) {
          _e('V7', '$path.page', 'entier >= 1 attendu');
        }
    }
  }

  void _enum(
    Object? v,
    Set<String> allowed,
    String path, {
    String rule = 'V7',
  }) {
    if (v is! String || !allowed.contains(v)) {
      _e(rule, path, 'valeur hors de ${allowed.join(' | ')} : $v');
    }
  }

  /// Liste de valeurs d'une liste fermée, sans doublon ; vide refusée si
  /// [nonEmpty]. Rend les valeurs valides lues.
  List<String> _enumList(
    Object? v,
    Set<String> allowed,
    String path,
    String rule, {
    bool nonEmpty = false,
  }) {
    if (v is! List) {
      _e(rule, path, 'liste attendue, trouvé : $v');
      return const [];
    }
    if (nonEmpty && v.isEmpty) {
      _e(rule, path, 'au moins une valeur attendue');
    }
    final seen = <String>[];
    for (final item in v) {
      _enum(item, allowed, path, rule: rule);
      if (item is String && allowed.contains(item)) {
        if (seen.contains(item)) {
          _e(rule, path, 'valeur en double : $item');
        } else {
          seen.add(item);
        }
      }
    }
    return seen;
  }

  /// V25 : cible sur la blanche.
  void _cueBallTarget(Json ill, String path) {
    final tip = ill['tip_point'];
    _enum(tip, _tipPoints, '$path.tip_point', rule: 'V25');
    if (ill.containsKey('compare')) {
      final compare = _enumList(
        ill['compare'],
        _tipPoints,
        '$path.compare',
        'V25',
      );
      if (tip is String && compare.contains(tip)) {
        _e(
          'V25',
          '$path.compare',
          "ne doit pas contenir le point d'impact lui-même : $tip",
        );
      }
    }
    if (ill.containsKey('cue_height')) {
      _enum(ill['cue_height'], _cueHeights, '$path.cue_height', rule: 'V25');
    }
    _tipOffset(ill, path);
  }

  /// V25 : écart du procédé (`contact` et `cue_ball_target`).
  void _tipOffset(Json ill, String path) {
    if (ill.containsKey('offset')) {
      _enum(ill['offset'], _tipOffsets, '$path.offset', rule: 'V25');
      if (ill['tip_point'] == 'center') {
        _e('V25', '$path.offset', 'sans objet pour un procédé au centre');
      }
    }
    if (ill.containsKey('paths') && ill['paths'] is! bool) {
      _e('V25', '$path.paths', 'booléen attendu');
    }
  }

  /// V26 : joueur schématique.
  void _playerFigure(Json ill, String path) {
    final view = ill['view'];
    _enum(view, _playerViews, '$path.view', rule: 'V26');
    if (ill.containsKey('focus')) {
      _enumList(
        ill['focus'],
        _playerMarks,
        '$path.focus',
        'V26',
        nonEmpty: true,
      );
    }
    if (ill.containsKey('lead_eye')) {
      _enum(ill['lead_eye'], _leadEyes, '$path.lead_eye', rule: 'V26');
    }
    if (ill.containsKey('head_case')) {
      _enum(ill['head_case'], _headCases, '$path.head_case', rule: 'V26');
      if (view == 'side') {
        _e(
          'V26',
          '$path.head_case',
          'la place de la tête se lit de dessus (view: top ou both)',
        );
      }
    }
    if (ill.containsKey('bridge')) {
      _enum(ill['bridge'], _bridges, '$path.bridge', rule: 'V26');
    }
    if (ill.containsKey('handedness')) {
      _enum(ill['handedness'], _handedness, '$path.handedness', rule: 'V26');
    }
  }

  /// V27 : plan amplitude × vitesse.
  void _powerRatio(Json ill, String path) {
    final raw = ill['points'];
    var count = 0;
    if (ill.containsKey('points')) {
      if (raw is! List) {
        _e('V27', '$path.points', 'liste attendue, trouvé : $raw');
      } else {
        count = raw.length;
        if (raw.length > _maxPowerPoints) {
          _e(
            'V27',
            '$path.points',
            'au plus $_maxPowerPoints exemples par illustration',
          );
        }
        for (var i = 0; i < raw.length; i++) {
          final point = raw[i];
          final at = '$path.points[$i]';
          if (point is! Json) {
            _e('V27', at, 'objet attendu');
            continue;
          }
          _enum(point['amplitude'], _amplitudes, '$at.amplitude', rule: 'V27');
          _enum(point['speed'], _speeds, '$at.speed', rule: 'V27');
          for (final key in point.keys) {
            if (!_powerPointKeys.contains(key)) {
              _e('V1', '$at.$key', 'clé inconnue pour un exemple');
            }
          }
        }
      }
    }
    final h = ill['highlight'];
    if (ill.containsKey('highlight') && (h is! int || h < 0 || h >= count)) {
      _e(
        'V27',
        '$path.highlight',
        "indice d'un exemple de points attendu (0 à ${count - 1}) : $h",
      );
    }
  }

  List<double>? _point(Object? v, String path, String rule) {
    final p = pointOf(v);
    if (p == null) {
      _e(rule, path, '[x, y] numérique attendu');
    }
    return p;
  }

  void _ghostAim(Json ill, String path) {
    for (final f in ['cue', 'object']) {
      final p = _point(ill[f], '$path.$f', 'V17');
      if (p != null && (p[0] < 0 || p[0] > 8 || p[1] < 0 || p[1] > 4)) {
        _e('V17', '$path.$f', 'hors de la table [0,8] x [0,4] : $p');
      }
    }
    final pocket = ill['pocket'];
    if (pocket is! String || !pockets.containsKey(pocket)) {
      _e('V17', '$path.pocket', 'poche inconnue : $pocket');
    }
    final fraction = ill['fraction'];
    if (fraction is! String || !_fractions.contains(fraction)) {
      _e('V17', '$path.fraction', 'fraction inconnue : $fraction');
    }
    _ghostAimGeometry(ill, path);
  }

  /// V17 : la quantité annoncée est cohérente avec la géométrie.
  ///
  /// `d = s · sin θ` (distance entre la ligne de visée et le centre de la
  /// bille de but, en cases) est comparée à la valeur nominale de l'étiquette,
  /// à 0,07 · s près.
  void _ghostAimGeometry(Json ill, String path) {
    final cue = _quiet(ill['cue']);
    final object = _quiet(ill['object']);
    final pocketName = ill['pocket'];
    final fractionName = ill['fraction'];
    if (cue == null || object == null) return;
    if (pocketName is! String || fractionName is! String) return;
    if ([...cue, ...object].any((v) => v < 0) ||
        cue[0] > 8 ||
        object[0] > 8 ||
        cue[1] > 4 ||
        object[1] > 4) {
      return;
    }
    TablePocket? pocket;
    for (final p in TablePocket.values) {
      if (p.name == pocketName) pocket = p;
    }
    ContactFraction? fraction;
    for (final f in ContactFraction.values) {
      if (_snake(f.name) == fractionName) fraction = f;
    }
    if (pocket == null || fraction == null) return;
    final gap = ghostAimDeviation(
      cue: Point(cue[0], cue[1]),
      object: Point(object[0], object[1]),
      pocket: pocket,
      fraction: fraction,
    );
    final tolerance = ghostAimTolerance();
    if (gap > tolerance) {
      _e(
        'V17',
        '$path.fraction',
        'incohérente avec la géométrie : écart ${gap.toStringAsFixed(4)} case '
            '> ${tolerance.toStringAsFixed(4)} (0,07 s) pour « $fractionName »',
      );
    }
  }

  static List<double>? _quiet(Object? value) {
    if (value is List && value.length == 2) {
      final x = value[0];
      final y = value[1];
      if (x is num && y is num) return [x.toDouble(), y.toDouble()];
    }
    return null;
  }

  static String _snake(String camel) =>
      camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  /// Une illustration `table` a la forme d'un diagramme (FORMAT des
  /// diagrammes) : on le fait contrôler par le validateur de diagrammes.
  void _tableIllustration(Json ill, String path) {
    if (ill['balls'] is! List) {
      _e(
        'V7',
        '$path.balls',
        'table « ${ill['id']} » : liste de billes attendue',
      );
      return;
    }
    final diagram = <String, Object?>{
      'id': 'illustration',
      'kind': 'exercise',
      'caption': '${ill['caption'] ?? 'x'}',
      'description': '${ill['alt'] ?? 'x'}',
      'uncertainties': <Object?>[],
      'table': {'view': 'top', 'head_end': 'left'},
      'balls': ill['balls'],
      for (final k in ['ghosts', 'arrows', 'zones', 'sequence'])
        if (ill.containsKey(k)) k: ill[k],
    };
    final report = validateDiagramFile(
      jsonEncode({
        'version': 1,
        'source': {'file': 'illustration', 'page': 1},
        'diagrams': [diagram],
      }),
    );
    for (final e in report.errors) {
      _e('V7', path, 'table « ${ill['id']} » : $e');
    }
  }

  // --- entraînement (V4, V5, V6, V10, V11, V13, V20) ------------------------

  void _training() {
    final training = _map(doc['training'], 'training');
    if (training == null) return;
    _keys(training, 'training', _trainingKeys);
    _recallSlot(training['recall_slot']);
    final list = _list(training['exercises'], 'training.exercises');
    if (list == null) return;
    final ids = <String>{};
    final used = <int>{};
    for (var i = 0; i < list.length; i++) {
      final path = 'training.exercises[$i]';
      final ex = _map(list[i], path);
      if (ex == null) continue;
      _exercise(ex, path, ids, used);
    }
  }

  // --- créneau de rappel (V28, ADR 0011) ---------------------------------

  void _recallSlot(Object? raw) {
    const path = 'training.recall_slot';
    final order = doc['order'];
    if (raw == null) {
      if (order is int && order > 1) {
        _e('V28', path, 'créneau de rappel obligatoire dès order 2');
      }
      return;
    }
    if (order == 1) {
      _e('V28', path, 'interdit à la première séance (order 1)');
    }
    final slot = _map(raw, path);
    if (slot == null) return;
    _keys(slot, path, _recallSlotKeys);
    final weights = _weights(slot['weight'], '$path.weight');
    for (final a in const ['children', 'adults']) {
      if (!weights.containsKey(a)) {
        _e('V28', '$path.weight', 'poids $a obligatoire (créneau affiché)');
      }
    }
    final passes = slot['passes'];
    if (passes is! int || passes < 1 || passes > 2) {
      _e('V28', '$path.passes', 'passes doit valoir 1 ou 2 : $passes');
    }
  }

  void _exercise(Json ex, String path, Set<String> ids, Set<int> used) {
    _keys(ex, path, _exerciseKeys);
    final exId = ex['id'];
    _localId(exId, '$path.id', ids);
    _text(ex['title'], '$path.title');
    final weights = _weights(ex['weight'], '$path.weight');
    for (final a in weights.keys) {
      _exercises[a]!.add('$exId');
    }
    final n = _ref(ex, path, used);
    _diagram(ex['diagram'], path, n);
    final passes = ex['passes'];
    if (passes is! int || passes < 1 || passes > 2) {
      _e('V10', '$path.passes', 'passes doit valoir 1 ou 2 : $passes');
    }
    _exerciseTexts(ex, path);
    final mistakes = _list(ex['mistakes'], '$path.mistakes');
    if (mistakes != null) {
      if (mistakes.length > 3) {
        _e('V1', '$path.mistakes', '0 à 3 erreurs attendues');
      }
      for (var j = 0; j < mistakes.length; j++) {
        final m = _map(mistakes[j], '$path.mistakes[$j]');
        if (m == null) continue;
        _keys(m, '$path.mistakes[$j]', _mistakeKeys);
        _text(m['symptom'], '$path.mistakes[$j].symptom');
        _text(m['fix'], '$path.mistakes[$j].fix');
      }
    }
    _playful(ex['playful'], '$path.playful');
    final src = _src(ex['src'], '$path.src');
    final block = _block;
    if (src != null && block != null) {
      if (src != 'S' && src != 'Prop') {
        _e('V13', '$path.src', 'S ou Prop attendu pour un exercice : $src');
      } else if (src != block.source) {
        _e(
          'V13',
          '$path.src',
          'src $src différent de la source du bloc ${block.id} '
              '(${block.source})',
        );
      }
    }
  }

  int? _ref(Json ex, String path, Set<int> used) {
    final raw = ex['ref'];
    if (raw is! Map<String, Object?>) {
      _e('V4', '$path.ref', 'ExerciseRef {block, n} obligatoire');
      return null;
    }
    _keys(raw, '$path.ref', _refKeys);
    final block = raw['block'];
    final n = raw['n'];
    final expected = doc['catalogue_block'];
    if (block != expected) {
      _e('V4', '$path.ref.block', 'attendu $expected, trouvé $block');
    }
    if (n is! int) {
      _e('V4', '$path.ref.n', 'entier attendu');
      return null;
    }
    final catalogueBlock = block is String ? _structure.blocks[block] : null;
    if (catalogueBlock != null && !catalogueBlock.exercises.contains(n)) {
      _e('V4', '$path.ref.n', 'exercice $n absent du bloc $block');
    }
    final slot = _slot;
    if (slot != null && !slot.exercises.contains(n)) {
      _e(
        'V5',
        '$path.ref.n',
        'exercice $n hors de la tranche ${_range(slot.exercises)} '
            'de ${slot.id}',
      );
    }
    if (!used.add(n)) {
      _e('V5', '$path.ref.n', 'exercice $n en double dans la séance');
    }
    return n;
  }

  void _diagram(Object? raw, String path, int? n) {
    if (raw is! String || raw.isEmpty) {
      _e('V6', '$path.diagram', 'identifiant de diagramme obligatoire');
      return;
    }
    final d = ctx.diagrams[raw];
    if (d == null) {
      _e('V6', '$path.diagram', 'diagramme inconnu : $raw');
      return;
    }
    final block = _block;
    if (d.kind != 'exercise') {
      _e(
        'V6',
        '$path.diagram',
        'kind $raw : exercise attendu, trouvé ${d.kind}',
      );
    }
    if (block == null) return;
    if (d.sheet != block.title) {
      _e(
        'V6',
        '$path.diagram',
        'sheet de $raw : « ${block.title} » attendu, trouvé « ${d.sheet} »',
      );
    }
    if (n != null && d.exercise != n) {
      _e(
        'V6',
        '$path.diagram',
        'exercise de $raw : $n attendu, trouvé ${d.exercise}',
      );
    }
    if (block.source == 'Prop' &&
        (d.folder != 'proposition' || d.rank != 'Prop')) {
      _e(
        'V6',
        '$path.diagram',
        'bloc [Prop] : diagramme attendu dans proposition/ avec rank Prop '
            '($raw : ${d.folder}, ${d.rank})',
      );
    }
    if (block.source == 'S' && d.folder != 'entrainement') {
      _e(
        'V6',
        '$path.diagram',
        'bloc sourcé : diagramme attendu dans entrainement/ ($raw : ${d.folder})',
      );
    }
  }

  void _exerciseTexts(Json ex, String path) {
    for (final f in ['setup', 'instruction', 'expected']) {
      final t = _text(ex[f], '$path.$f');
      if (t == null) continue;
      if (_rate.hasMatch(t)) {
        _e('V10', '$path.$f', 'taux interdit (il vient du catalogue)');
      }
      if (RegExp('chevalet', caseSensitive: false).hasMatch(t)) {
        _e(
          'V10',
          '$path.$f',
          'mot « chevalet » interdit (lu dans le catalogue)',
        );
      }
      if (_ballCount.hasMatch(t)) {
        _e(
          'V10',
          '$path.$f',
          'nombre de billes interdit : écrire « les billes du schéma »',
        );
      }
      if (RegExp('bronze', caseSensitive: false).hasMatch(t)) {
        _e('V10', '$path.$f', 'mention « bronze » interdite');
      }
    }
  }

  void _playful(Object? raw, String path) {
    if (raw is! Map<String, Object?>) {
      _e('V20', path, 'playful obligatoire (hook, challenge)');
      return;
    }
    _keys(raw, path, _playfulKeys);
    for (final f in ['hook', 'challenge']) {
      final v = raw[f];
      if (v is! String || v.trim().isEmpty) {
        _e('V20', '$path.$f', 'texte non vide obligatoire');
      }
    }
  }

  // --- jeu (V11, V13, V14, V20) --------------------------------------------

  void _game() {
    final game = _map(doc['game'], 'game');
    if (game == null) return;
    _keys(game, 'game', _gameKeys);
    for (final f in ['title', 'players', 'scoring', 'end']) {
      _text(game[f], 'game.$f');
    }
    final materials = game['materials'];
    if (materials != null && materials is! String) {
      _e('V1', 'game.materials', 'texte ou null attendu');
    }
    final rules = _list(game['rules'], 'game.rules');
    if (rules != null) {
      if (rules.isEmpty) _e('V1', 'game.rules', 'au moins une règle attendue');
      for (var i = 0; i < rules.length; i++) {
        _text(rules[i], 'game.rules[$i]');
      }
    }
    final setup = game['setup_illustration'];
    if (setup != null) {
      _citedIllustrations.add(('game.setup_illustration', setup));
    }
    final weights = _weights(game['weight'], 'game.weight');
    for (final a in _audiences) {
      if (!weights.containsKey(a)) {
        _e('V11', 'game.weight', 'jeu non affiché pour $a (poids obligatoire)');
      }
    }
    final variant = game['playful_variant'];
    if (variant is! String || variant.trim().isEmpty) {
      _e('V20', 'game.playful_variant', 'texte non vide obligatoire');
    }
    final adaptation = _map(game['adaptation'], 'game.adaptation');
    if (adaptation != null) {
      _keys(adaptation, 'game.adaptation', _adaptationKeys);
      for (final a in _audiences) {
        final v = adaptation[a];
        if (v != null && v is! String) {
          _e('V1', 'game.adaptation.$a', 'texte ou null attendu');
        }
      }
    }
    final src = _src(game['src'], 'game.src');
    final adapted = game['adapted'];
    if (adapted is! bool) _e('V13', 'game.adapted', 'booléen attendu');
    if (adapted == true && src != null && src != 'Prop') {
      _e('V13', 'game.src', 'un jeu adapté doit être [Prop]');
    }
    final source = game['source_game'];
    if (source == null) {
      if (src != null && src != 'Prop') {
        _e(
          'V13',
          'game.src',
          'un jeu sans source (source_game null) est [Prop]',
        );
      }
    } else if (source is! int || !ctx.games.contains(source)) {
      _e('V13', 'game.source_game', 'jeu $source absent de jeux.md');
    }
    _linkPrevious(game);
  }

  void _linkPrevious(Json game) {
    final order = _slot?.order ?? _order;
    final has = game.containsKey('link_previous');
    if (order == 1) {
      if (has) {
        _e('V14', 'game.link_previous', 'absent pour order 1');
      }
      return;
    }
    if (!has) {
      _e('V14', 'game.link_previous', 'obligatoire pour order > 1');
      return;
    }
    final link = _map(game['link_previous'], 'game.link_previous', rule: 'V14');
    if (link == null) return;
    _keys(link, 'game.link_previous', _linkKeys);
    if (_hasPreviousKey && link['notion_of'] != _previous) {
      _e(
        'V14',
        'game.link_previous.notion_of',
        'doit être previous ($_previous), trouvé ${link['notion_of']}',
      );
    }
    for (final f in ['rule', 'note']) {
      final v = link[f];
      if (v is! String || v.trim().isEmpty) {
        _e('V14', 'game.link_previous.$f', 'texte non vide obligatoire');
      }
    }
  }

  // --- bilan, sources ------------------------------------------------------

  void _review() {
    final review = _map(doc['review'], 'review');
    if (review == null) return;
    _keys(review, 'review', _reviewKeys);
    final prompts = _list(review['prompts'], 'review.prompts');
    if (prompts == null) return;
    if (prompts.length < 2 || prompts.length > 3) {
      _e('V1', 'review.prompts', '2 à 3 questions attendues');
    }
    for (var i = 0; i < prompts.length; i++) {
      _text(prompts[i], 'review.prompts[$i]');
    }
  }

  void _sourcesRule() {
    final raw = doc['sources'];
    final list = _list(raw, 'sources', rule: 'V18');
    if (list == null) return;
    if (list.isEmpty) {
      _e('V18', 'sources', 'au moins une source obligatoire');
    }
    var hasS = false;
    for (var i = 0; i < list.length; i++) {
      final path = 'sources[$i]';
      final s = _map(list[i], path, rule: 'V18');
      if (s == null) continue;
      _keys(s, path, _sourceKeys);
      final rank = s['rank'];
      if (rank is! String || !_sourceRanks.contains(rank)) {
        _e('V18', '$path.rank', 'S, FFB ou Web attendu : $rank');
      }
      final file = s['file'];
      if (file is! String || file.trim().isEmpty) {
        _e('V18', '$path.file', 'nom de fichier obligatoire');
      } else if (rank == 'S') {
        hasS = true;
        if (!ctx.sourceFiles.contains(file)) {
          _e('V18', '$path.file', '« $file » absent de docs/sources/');
        }
      }
      final page = s['page'];
      if (page != null && (page is! int || page < 1)) {
        _e('V18', '$path.page', 'entier >= 1 ou null attendu');
      }
      _text(s['note'], '$path.note', rule: 'V18');
    }
    final training = doc['training'];
    final exercises = training is Map ? training['exercises'] : null;
    if (!hasS && exercises is List) {
      for (final e in exercises) {
        if (e is Map && e['src'] == 'Prop') {
          _e(
            'V18',
            'sources',
            "un exercice Prop est adapté d'une fiche [S] : au moins une "
                'source rank S est obligatoire',
          );
          break;
        }
      }
    }
  }

  // --- règles transversales -------------------------------------------------

  void _referencesToIllustrations() {
    for (final (path, ref) in _citedIllustrations) {
      if (ref is! String || !_illustrationIds.contains(ref)) {
        _e('V7', path, 'illustration citée mais absente : $ref');
      }
    }
  }

  /// V24 : une illustration que rien ne cite (théorie, initiation, jeu) et
  /// que la séance suivante ne reprend pas en rappel n'est jamais visible.
  /// Contrôlée seulement quand les séances qui pourraient la reprendre sont
  /// toutes connues (mode partiel : fichiers absents ignorés).
  void _orphanIllustrations() {
    final id = doc['id'];
    final items = doc['illustrations'];
    if (id is! String || items is! List) return;
    final cited = {
      for (final (_, ref) in _citedIllustrations)
        if (ref is String) ref,
    };
    final next = [
      for (final slot in _structure.slots)
        if (slot.previous == id) slot.id,
    ];
    for (final nextId in next) {
      final sibling = siblings[nextId];
      if (sibling == null) return;
      final recall = sibling['recall'];
      final reuse = recall is Map ? recall['reuse'] : null;
      if (reuse is Map && reuse['sheet'] == id) {
        final illustration = reuse['illustration'];
        if (illustration is String) cited.add(illustration);
      }
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final itemId = item is Map ? item['id'] : null;
      if (itemId is String && !cited.contains(itemId)) {
        _e(
          'V24',
          'illustrations[$i]',
          'illustration jamais citée (théorie, initiation, jeu) ni reprise '
              'en rappel par la séance suivante : $itemId',
        );
      }
    }
  }

  void _weightsMinimum() {
    for (final a in _audiences) {
      if (_sections[a]! < 1) {
        _e('V11', 'theory.sections', 'aucune section de théorie pour $a');
      }
      if (_exercises[a]!.length < 2) {
        _e(
          'V11',
          'training.exercises',
          'moins de 2 exercices affichés pour $a',
        );
      }
    }
  }

  void _imagePaths() {
    for (final s in _strings(doc)) {
      if (_imagePath.hasMatch(s)) {
        _e('V8', 'séance', 'chemin de fichier image interdit : $s');
        return;
      }
    }
  }

  void _officialWord() {
    final official = RegExp('officiel', caseSensitive: false);
    void scan(String path, Object? node) {
      for (final s in _strings(node)) {
        if (official.hasMatch(s)) {
          _e(
            'V19',
            path,
            'le mot « officiel » ne doit pas qualifier une proposition',
          );
          return;
        }
      }
    }

    final recall = doc['recall'];
    if (recall is Map && recall['src'] == 'Prop') scan('recall', recall);
    final theory = doc['theory'];
    if (theory is Map && theory['sections'] is List) {
      final sections = theory['sections']! as List;
      for (var i = 0; i < sections.length; i++) {
        final s = sections[i];
        if (s is Map && s['src'] == 'Prop') scan('theory.sections[$i]', s);
      }
    }
    final initiation = doc['initiation'];
    if (initiation is List) {
      for (var i = 0; i < initiation.length; i++) {
        final s = initiation[i];
        if (s is Map && s['src'] == 'Prop') scan('initiation[$i]', s);
      }
    }
    final training = doc['training'];
    final exercises = training is Map ? training['exercises'] : null;
    if (exercises is List) {
      for (var i = 0; i < exercises.length; i++) {
        final e = exercises[i];
        if (e is! Map) continue;
        final p = 'training.exercises[$i]';
        if (e['src'] == 'Prop') scan(p, e);
        scan('$p.playful', e['playful']);
      }
    }
    scan('theme', doc['theme']);
    final game = doc['game'];
    if (game is Map) {
      if (game['src'] == 'Prop' || game['adapted'] == true) {
        scan('game', game);
      }
      for (final k in ['playful_variant', 'link_previous', 'adaptation']) {
        scan('game.$k', game[k]);
      }
    }
  }

  void _sourcesPath() {
    for (final entry in doc.entries) {
      final node = entry.value;
      // Seul `sources[].file` peut citer un chemin de docs/sources/.
      final scanned = entry.key == 'sources' && node is List
          ? [
              for (final s in node)
                if (s is Map) s['note'],
            ]
          : node;
      for (final s in _strings(scanned)) {
        if (s.contains('docs/sources')) {
          _e(
            'V19',
            entry.key,
            'chemin docs/sources interdit hors de sources[].file',
          );
          return;
        }
      }
    }
  }

  // --- utilitaires ---------------------------------------------------------

  String? _src(Object? v, String path) {
    if (v is String && _srcValues.contains(v)) return v;
    _e('V13', path, 'src obligatoire : S, FFB, Web ou Prop (trouvé $v)');
    return null;
  }

  void _localId(Object? v, String path, Set<String> seen) {
    if (v is! String || !_slug.hasMatch(v)) {
      _e('V1', path, 'slug local attendu : $v');
    } else if (!seen.add(v)) {
      _e('V1', path, 'identifiant en double : $v');
    }
  }

  /// Poids d'un élément : public -> entier >= 1 (V11).
  Map<String, int> _weights(Object? raw, String path) {
    final out = <String, int>{};
    final m = _map(raw, path);
    if (m == null) return out;
    for (final key in m.keys) {
      if (!_audiences.contains(key)) {
        _e('V1', '$path.$key', 'clé inconnue (children, adults)');
      }
    }
    for (final a in _audiences) {
      if (!m.containsKey(a)) continue;
      final v = m[a];
      if (v is int && v >= 1) {
        out[a] = v;
      } else {
        _e('V11', '$path.$a', 'poids entier >= 1 attendu : $v');
      }
    }
    return out;
  }

  String _range(List<int> n) =>
      n.length == 1 ? '${n.first}' : '${n.first}-${n.last}';
}
