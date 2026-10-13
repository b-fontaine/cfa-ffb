import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/session_range.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:yaml/yaml.dart';

const _bridges = <String, Bridge>{
  'cadre': Bridge.frame,
  'surface': Bridge.surface,
};

/// Champ `source` : absent ou `S` = `[S]`, `Prop` = proposition ; toute autre
/// valeur est refusée.
Provenance _source(Object? raw) => switch (raw) {
  null || 'S' => Provenance.s,
  'Prop' => Provenance.prop,
  _ => throw const InvariantViolation(InvariantCode.invalidCatalogue),
};

/// Lit le YAML versionné `docs/knowledge/03-exercices/catalogue-entrainement.yaml`
/// (copié en asset) et construit le catalogue du domaine, blocs triés par
/// `teaching_order` (ordre d'enseignement, distinct de l'ordre du fichier).
///
/// Toute structure inattendue lève [InvariantViolation] (`invalidCatalogue`).
ExerciseCatalogue parseCatalogue(String source) {
  try {
    final root = loadYaml(source) as YamlMap;
    final validation = root['validation'] as YamlMap;
    return ExerciseCatalogue(
      version: root['version'] as int,
      level: root['level'] as int,
      defaultPassesRequired: validation['passes_required_default'] as int,
      blocks: [
        for (final block in root['blocks'] as YamlList)
          _parseBlock(block as YamlMap),
      ]..sort((a, b) => a.teachingOrder.compareTo(b.teachingOrder)),
    );
  } on Failure {
    rethrow;
  } on Object {
    throw const InvariantViolation(InvariantCode.invalidCatalogue);
  }
}

TrainingBlock _parseBlock(YamlMap block) {
  final id = block['id'] as String;
  final sessions = block['sessions'] as YamlMap;
  final sheets = block['technical_sheet'];
  return TrainingBlock(
    id: id,
    title: block['title'] as String,
    teachingOrder: block['teaching_order'] as int,
    recommendedSessions: SessionRange(
      min: sessions['min'] as int,
      max: sessions['max'] as int,
    ),
    technicalSheets: sheets is YamlList ? sheets.cast<int>() : [sheets as int],
    duplicateInSource: block['duplicate_in_source'] == true,
    source: _source(block['source']),
    exercises: [
      for (final exercise in block['exercises'] as YamlList)
        _parseExercise(id, exercise as YamlMap),
    ],
  );
}

ExerciseSpec _parseExercise(String blockId, YamlMap exercise) {
  final rate = exercise['rate'] as YamlList;
  final bridge = exercise['bridge'] as String?;
  return ExerciseSpec(
    ref: ExerciseRef(blockId: blockId, number: exercise['n'] as int),
    rate: SuccessRate(successes: rate[0] as int, attempts: rate[1] as int),
    bridge: bridge == null ? null : _bridges[bridge]!,
    bronze: exercise['bronze'] == true,
    note: exercise['note'] as String?,
    source: _source(exercise['source']),
  );
}
