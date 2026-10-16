import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'season_archive.freezed.dart';

/// Nombre minimal d'élèves distincts pour qu'une ligne par exercice soit
/// conservée dans l'archive (ADR 0019). C'est une règle, pas un réglage : une
/// ligne « 1 élève adulte, 4 passages » décrirait une personne reconnaissable.
const minCohortForFigures = 3;

const _invalid = InvariantViolation(InvariantCode.backupInvalid);
const _inconsistent = InvariantViolation(InvariantCode.backupInconsistent);

/// Chiffres d'une saison pour un public : agrégats seulement, aucun
/// identifiant d'élève, aucun groupe, aucune date de séance. Sous
/// [minCohortForFigures] élèves présents, seuls le nombre de séances et celui
/// d'élèves sont gardés : présences et passages décriraient ces élèves.
@freezed
abstract class AudienceArchive with _$AudienceArchive {
  factory AudienceArchive({
    required Audience audience,
    required int sessionCount,
    required int presenceCount,
    required int possiblePresenceCount,

    /// Élèves distincts présents au moins une fois.
    required int studentCount,
    required int attemptCount,
  }) = _AudienceArchive;

  AudienceArchive._() {
    final counts = [
      sessionCount,
      presenceCount,
      possiblePresenceCount,
      studentCount,
      attemptCount,
    ];
    if (counts.any((count) => count < 0) ||
        presenceCount > possiblePresenceCount) {
      throw _invalid;
    }
    if (studentCount < minCohortForFigures &&
        (presenceCount != 0 ||
            possiblePresenceCount != 0 ||
            attemptCount != 0)) {
      throw _invalid;
    }
  }
}

/// Chiffres d'un exercice pour un public ; n'existe qu'à partir de
/// [minCohortForFigures] élèves distincts.
@freezed
abstract class ExerciseArchive with _$ExerciseArchive {
  factory ExerciseArchive({
    required Audience audience,
    required ExerciseRef exercise,
    required int studentCount,
    required int attemptCount,

    /// Billes empochées et tentées, cumulées sur tous les passages.
    required int potted,
    required int total,
  }) = _ExerciseArchive;

  ExerciseArchive._() {
    if (studentCount < minCohortForFigures ||
        attemptCount < 0 ||
        potted < 0 ||
        potted > total) {
      throw _invalid;
    }
  }
}

/// Archive non nominative d'une saison close, calculée avant l'effacement des
/// élèves (ADR 0019). Un bloc au plus par public, une ligne au plus par
/// exercice et par public.
@freezed
abstract class SeasonArchive with _$SeasonArchive {
  factory SeasonArchive({
    required SeasonId seasonId,
    required List<AudienceArchive> audiences,
    required List<ExerciseArchive> exercises,
  }) = _SeasonArchive;

  SeasonArchive._() {
    final audienceKeys = {for (final a in audiences) a.audience};
    final exerciseKeys = {for (final e in exercises) (e.audience, e.exercise)};
    if (audienceKeys.length != audiences.length ||
        exerciseKeys.length != exercises.length) {
      throw _inconsistent;
    }
  }

  /// Le bloc du public, ou `null` s'il n'y a eu aucune séance pour lui.
  AudienceArchive? audienceOf(Audience audience) {
    for (final block in audiences) {
      if (block.audience == audience) return block;
    }
    return null;
  }
}
