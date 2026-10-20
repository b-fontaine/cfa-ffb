import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Identifiants **déterministes** de documents Firestore composés à partir de
/// leur contenu (ADR 0024, décision 14). Ils vivent en code pur : les dépôts
/// (`ClubPaths`) et le plan d'import (FB7, domaine) doivent écrire le même.
abstract final class DocumentIds {
  /// Une appartenance datée : `groupId_studentId_from` ; [from] est lu en ISO
  /// 8601 (fuseau conservé, microsecondes comprises).
  static String membership(GroupId group, StudentId student, DateTime from) =>
      '${group.value}_${student.value}_${from.toIso8601String()}';

  /// Le document de synthèse d'une saison pour un public.
  static String archiveSummary(SeasonId season, Audience audience) =>
      '${season.value}_${audience.name}';

  /// Le document d'un exercice d'une saison pour un public.
  static String archiveExercise(
    SeasonId season,
    Audience audience,
    ExerciseRef exercise,
  ) =>
      '${season.value}_${audience.name}_${exercise.blockId}_${exercise.number}';
}
