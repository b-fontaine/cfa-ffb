import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/document_ids.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance archive de saison <-> documents `clubs/{c}/archives/{id}`
/// (liste blanche de `archiveShape`) : **un document de synthèse par saison et
/// public** (`{saison}_{public}`) et **un par exercice et public**
/// (`{saison}_{public}_{bloc}_{numéro}`). Aucun identifiant d'élève ni de
/// groupe : des compteurs seulement. Un document d'exercice se reconnaît à son
/// champ `blockId`.
abstract final class SeasonArchiveDocument {
  static String summaryId(SeasonId season, Audience audience) =>
      DocumentIds.archiveSummary(season, audience);

  static String exerciseId(
    SeasonId season,
    Audience audience,
    ExerciseRef exercise,
  ) => DocumentIds.archiveExercise(season, audience, exercise);

  static Fields encodeAudience(SeasonId season, AudienceArchive block) => {
    'seasonId': season.value,
    'public': block.audience.name,
    'sessionCount': block.sessionCount,
    'presenceCount': block.presenceCount,
    'possiblePresenceCount': block.possiblePresenceCount,
    'studentCount': block.studentCount,
    'attemptCount': block.attemptCount,
    'createdAt': serverTimestamp,
  };

  static Fields encodeExercise(SeasonId season, ExerciseArchive line) => {
    'seasonId': season.value,
    'public': line.audience.name,
    'blockId': line.exercise.blockId,
    'exerciseNumber': line.exercise.number,
    'studentCount': line.studentCount,
    'attemptCount': line.attemptCount,
    'potted': line.potted,
    'total': line.total,
    'createdAt': serverTimestamp,
  };

  /// Les archives (une par saison, triées par identifiant) des documents lus.
  static List<SeasonArchive> decodeAll(List<StoredDocument> documents) {
    final bySeason = <String, List<StoredDocument>>{};
    for (final document in documents) {
      final season = DocumentValues(
        document.path,
        document.fields,
      ).string('seasonId');
      bySeason.putIfAbsent(season, () => []).add(document);
    }
    final seasons = bySeason.keys.toList()..sort();
    try {
      return [
        for (final season in seasons)
          _decodeSeason(SeasonId(season), bySeason[season]!),
      ];
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed archive: ${violation.code.name}',
      );
    }
  }

  static SeasonArchive _decodeSeason(
    SeasonId season,
    List<StoredDocument> documents,
  ) {
    final audiences = <AudienceArchive>[];
    final exercises = <ExerciseArchive>[];
    for (final document in documents) {
      final values = DocumentValues(document.path, document.fields);
      final audience = _audience(values.string('public'), document.path);
      if (document.fields.containsKey('blockId')) {
        exercises.add(
          ExerciseArchive(
            audience: audience,
            exercise: ExerciseRef(
              blockId: values.string('blockId'),
              number: values.integer('exerciseNumber', fallback: 0),
            ),
            studentCount: values.integer('studentCount', fallback: 0),
            attemptCount: values.integer('attemptCount', fallback: 0),
            potted: values.integer('potted', fallback: 0),
            total: values.integer('total', fallback: 0),
          ),
        );
      } else {
        audiences.add(
          AudienceArchive(
            audience: audience,
            sessionCount: values.integer('sessionCount', fallback: 0),
            presenceCount: values.integer('presenceCount', fallback: 0),
            possiblePresenceCount: values.integer(
              'possiblePresenceCount',
              fallback: 0,
            ),
            studentCount: values.integer('studentCount', fallback: 0),
            attemptCount: values.integer('attemptCount', fallback: 0),
          ),
        );
      }
    }
    int byAudience(Audience a, Audience b) => a.index.compareTo(b.index);
    audiences.sort((a, b) => byAudience(a.audience, b.audience));
    exercises.sort((a, b) {
      final audience = byAudience(a.audience, b.audience);
      if (audience != 0) return audience;
      final block = a.exercise.blockId.compareTo(b.exercise.blockId);
      return block != 0
          ? block
          : a.exercise.number.compareTo(b.exercise.number);
    });
    return SeasonArchive(
      seasonId: season,
      audiences: audiences,
      exercises: exercises,
    );
  }

  static Audience _audience(String name, String path) {
    for (final audience in Audience.values) {
      if (audience.name == name) return audience;
    }
    throw ServiceFailure(
      ServiceFailureCode.other,
      'malformed document $path: unknown audience',
    );
  }
}
