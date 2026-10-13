// Structure des séances du catalogue (FORMAT.md § 1), calculée depuis
// catalogue-entrainement.yaml : le nombre de parties n'est jamais une
// constante.
import 'package:yaml/yaml.dart';

import '../diagrammes/model.dart';

/// Un bloc du catalogue d'entraînement.
class CatalogueBlock {
  const CatalogueBlock({
    required this.id,
    required this.title,
    required this.source,
    required this.sessionsMin,
    required this.sessionsMax,
    required this.exercises,
  });

  final String id;
  final String title;

  /// `S` (Fiches Entrainement) ou `Prop` (bloc proposé).
  final String source;
  final int sessionsMin;
  final int sessionsMax;

  /// Numéros `n` des exercices, croissants.
  final List<int> exercises;
}

/// Une technique enseignée (FORMAT.md § 1.2). Cette liste est la seule
/// donnée codée en dur : titres, fiches et plages d'exercices partagées.
class TechniqueSpec {
  const TechniqueSpec({
    required this.slug,
    required this.blockId,
    required this.technicalSheets,
    required this.initiationSheets,
    this.firstExercise,
    this.lastExercise,
  });

  final String slug;
  final String blockId;
  final List<int> technicalSheets;

  /// Fiches d'initiation de la technique (aucune pour la bille fantôme).
  final List<int> initiationSheets;

  /// Plage d'exercices quand le bloc est partagé (quart et finesse).
  final int? firstExercise;
  final int? lastExercise;
}

/// Les 14 techniques, dans l'ordre d'enseignement `[U]` (rebond sur bande
/// avant rejet naturel).
const techniqueSpecs = <TechniqueSpec>[
  TechniqueSpec(
    slug: 'posture',
    blockId: 'posture',
    technicalSheets: [1],
    initiationSheets: [1, 2, 3, 4],
  ),
  TechniqueSpec(
    slug: 'puissance',
    blockId: 'puissance',
    technicalSheets: [2],
    initiationSheets: [5],
  ),
  TechniqueSpec(
    slug: 'bille-fantome',
    blockId: 'bille-fantome',
    technicalSheets: [3],
    initiationSheets: [],
  ),
  TechniqueSpec(
    slug: 'bille-pleine',
    blockId: 'bille-pleine',
    technicalSheets: [4],
    initiationSheets: [6],
  ),
  TechniqueSpec(
    slug: 'demi-bille',
    blockId: 'demi-bille',
    technicalSheets: [5],
    initiationSheets: [7],
  ),
  TechniqueSpec(
    slug: 'trois-quarts',
    blockId: 'trois-quarts',
    technicalSheets: [6],
    initiationSheets: [8],
  ),
  TechniqueSpec(
    slug: 'quart',
    blockId: 'quart-finesses',
    technicalSheets: [7],
    initiationSheets: [9],
    firstExercise: 1,
    lastExercise: 2,
  ),
  TechniqueSpec(
    slug: 'finesse',
    blockId: 'quart-finesses',
    technicalSheets: [8],
    initiationSheets: [9],
    firstExercise: 3,
    lastExercise: 4,
  ),
  TechniqueSpec(
    slug: 'rebond-bande',
    blockId: 'rebond-bande',
    technicalSheets: [9],
    initiationSheets: [11],
  ),
  TechniqueSpec(
    slug: 'rejet-naturel',
    blockId: 'rejet-naturel',
    technicalSheets: [10],
    initiationSheets: [12],
  ),
  TechniqueSpec(
    slug: 'coule',
    blockId: 'coule',
    technicalSheets: [11],
    initiationSheets: [13, 14],
  ),
  TechniqueSpec(
    slug: 'carreau',
    blockId: 'carreau',
    technicalSheets: [12],
    initiationSheets: [15],
  ),
  TechniqueSpec(
    slug: 'angle-droit',
    blockId: 'angle-droit',
    technicalSheets: [13],
    initiationSheets: [16],
  ),
  TechniqueSpec(
    slug: 'retro',
    blockId: 'retro',
    technicalSheets: [14],
    initiationSheets: [17, 18, 19],
  ),
];

/// Une séance attendue (une partie d'une technique).
class SessionSlot {
  const SessionSlot({
    required this.order,
    required this.id,
    required this.technique,
    required this.part,
    required this.parts,
    required this.blockId,
    required this.exercises,
    required this.previous,
  });

  /// Rang global, de 1 à 29.
  final int order;
  final String id;
  final String technique;
  final int part;
  final int parts;
  final String blockId;

  /// Numéros d'exercices du bloc attribués à cette partie.
  final List<int> exercises;

  /// Séance précédente dans l'ordre d'enseignement (`null` pour la 1re).
  final String? previous;

  String get fileName => '${order.toString().padLeft(2, '0')}-$id.yaml';
}

/// Résultat du calcul de structure.
class Structure {
  Structure({required this.blocks, required this.slots, required this.errors});

  final Map<String, CatalogueBlock> blocks;
  final List<SessionSlot> slots;

  /// Erreurs V2 (bloc manquant, `parties > N`...).
  final List<String> errors;

  /// Nombre de parties par technique valide.
  Map<String, int> get partsByTechnique => {
    for (final s in slots) s.technique: s.parts,
  };

  SessionSlot? slotById(String id) {
    for (final s in slots) {
      if (s.id == id) return s;
    }
    return null;
  }

  SessionSlot? slotFor(String technique, int part) {
    for (final s in slots) {
      if (s.technique == technique && s.part == part) return s;
    }
    return null;
  }

  List<SessionSlot> slotsOf(String technique) => [
    for (final s in slots)
      if (s.technique == technique) s,
  ];
}

/// Lit `catalogue-entrainement.yaml` (blocs, sessions, exercices).
Map<String, CatalogueBlock> parseCatalogue(String text) {
  final Object? doc;
  try {
    doc = toPlain(loadYaml(text));
  } on YamlException catch (e) {
    throw FormatException('catalogue : YAML invalide : ${e.message}');
  }
  if (doc is! Map<String, Object?> || doc['blocks'] is! List) {
    throw const FormatException('catalogue : liste « blocks » attendue');
  }
  final blocks = <String, CatalogueBlock>{};
  for (final raw in doc['blocks']! as List) {
    if (raw is! Map<String, Object?>) continue;
    final id = raw['id'];
    if (id is! String) continue;
    final sessions = raw['sessions'];
    final min = sessions is Map ? sessions['min'] : null;
    final max = sessions is Map ? sessions['max'] : null;
    final numbers = <int>[
      for (final e in (raw['exercises'] as List?) ?? const <Object?>[])
        if (e is Map && e['n'] is int) e['n']! as int,
    ]..sort();
    blocks[id] = CatalogueBlock(
      id: id,
      title: '${raw['title'] ?? id}',
      source: raw['source'] == 'Prop' ? 'Prop' : 'S',
      sessionsMin: min is int ? min : 1,
      sessionsMax: max is int ? max : 1,
      exercises: numbers,
    );
  }
  return blocks;
}

/// Calcule les parties, tranches, rangs et séances précédentes (FORMAT § 1).
Structure computeStructure(Map<String, CatalogueBlock> blocks) {
  final errors = <String>[];
  final slots = <SessionSlot>[];
  var order = 0;
  String? previous;
  for (final spec in techniqueSpecs) {
    final block = blocks[spec.blockId];
    if (block == null) {
      errors.add(
        'V2 : ${spec.slug} : bloc « ${spec.blockId} » absent du catalogue',
      );
      continue;
    }
    final first = spec.firstExercise;
    final last = spec.lastExercise;
    final numbers = [
      for (final n in block.exercises)
        if ((first == null || n >= first) && (last == null || n <= last)) n,
    ];
    if (first != null && last != null && numbers.length != last - first + 1) {
      errors.add(
        'V2 : ${spec.slug} : exercices $first à $last absents du bloc '
        '« ${spec.blockId} »',
      );
      continue;
    }
    final count = numbers.length;
    final ceilHalf = (count + 1) ~/ 2;
    final upper = block.sessionsMax < block.sessionsMin
        ? block.sessionsMin
        : block.sessionsMax;
    final wanted = ceilHalf.clamp(block.sessionsMin, upper);
    if (count == 0 || wanted > count) {
      errors.add(
        'V2 : ${spec.slug} : $wanted parties pour $count exercices '
        '(sessions ${block.sessionsMin}-${block.sessionsMax}) : technique '
        'invalide',
      );
      continue;
    }
    final base = count ~/ wanted;
    final extra = count % wanted;
    var from = 0;
    for (var part = 1; part <= wanted; part++) {
      final size = base + (part <= extra ? 1 : 0);
      order++;
      final id = '${spec.slug}-$part';
      slots.add(
        SessionSlot(
          order: order,
          id: id,
          technique: spec.slug,
          part: part,
          parts: wanted,
          blockId: spec.blockId,
          exercises: numbers.sublist(from, from + size),
          previous: previous,
        ),
      );
      from += size;
      previous = id;
    }
  }
  return Structure(blocks: blocks, slots: slots, errors: errors);
}

/// Spécification de technique par identifiant, ou `null`.
TechniqueSpec? techniqueSpec(String slug) {
  for (final s in techniqueSpecs) {
    if (s.slug == slug) return s;
  }
  return null;
}
