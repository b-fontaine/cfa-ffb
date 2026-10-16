import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Calcule l'archive agrégée et non nominative de [season] à partir de ses
/// séances, des appartenances de ses groupes et des passages (ADR 0019).
///
/// Doit être appelée **avant** l'effacement des élèves : ensuite, présences
/// et passages n'existent plus. Seules les séances de la saison comptent ;
/// un passage compte s'il appartient à l'une d'elles. Les lignes par exercice
/// n'existent qu'à partir de [minCohortForFigures] élèves distincts ; de même,
/// la ligne d'un public ne garde présences et passages qu'à partir de ce seuil
/// d'élèves présents. Rien dans
/// le résultat ne nomme un élève, un groupe ou une date de séance.
SeasonArchive buildArchive({
  required Season season,
  required Iterable<Group> groups,
  required Iterable<SessionRecord> sessions,
  required Iterable<ExerciseAttempt> attempts,
}) {
  final groupById = {
    for (final group in groups)
      if (group.seasonId == season.id) group.id: group,
  };
  final ofSeason = [
    for (final session in sessions)
      if (session.seasonId == season.id) session,
  ];
  final audienceOfSession = {
    for (final session in ofSeason) session.id: session.audience,
  };

  final audiences = <AudienceArchive>[];
  for (final audience in Audience.values) {
    final mine = [
      for (final session in ofSeason)
        if (session.audience == audience) session,
    ];
    if (mine.isEmpty) continue;
    var presences = 0;
    var possible = 0;
    final present = <StudentId>{};
    for (final session in mine) {
      final members = groupById[session.groupId]?.membersOn(session.date);
      presences += session.present.length;
      possible += {...?members, ...session.present}.length;
      present.addAll(session.present);
    }
    // Sous le seuil, présences et passages décriraient ces élèves : on ne
    // garde que le nombre de séances et d'élèves.
    final detailed = present.length >= minCohortForFigures;
    audiences.add(
      AudienceArchive(
        audience: audience,
        sessionCount: mine.length,
        presenceCount: detailed ? presences : 0,
        possiblePresenceCount: detailed ? possible : 0,
        studentCount: present.length,
        attemptCount: detailed
            ? attempts
                  .where((a) => audienceOfSession[a.sessionId] == audience)
                  .length
            : 0,
      ),
    );
  }

  final students = <(Audience, ExerciseRef), Set<StudentId>>{};
  final counts =
      <(Audience, ExerciseRef), ({int attempts, int potted, int total})>{};
  for (final attempt in attempts) {
    final audience = audienceOfSession[attempt.sessionId];
    if (audience == null) continue;
    final key = (audience, attempt.exercise);
    students.putIfAbsent(key, () => {}).add(attempt.studentId);
    final so = counts[key] ?? (attempts: 0, potted: 0, total: 0);
    counts[key] = (
      attempts: so.attempts + 1,
      potted: so.potted + attempt.potted,
      total: so.total + attempt.total,
    );
  }
  final lines =
      [
        for (final entry in counts.entries)
          if (students[entry.key]!.length >= minCohortForFigures)
            ExerciseArchive(
              audience: entry.key.$1,
              exercise: entry.key.$2,
              studentCount: students[entry.key]!.length,
              attemptCount: entry.value.attempts,
              potted: entry.value.potted,
              total: entry.value.total,
            ),
      ]..sort((a, b) {
        final byAudience = a.audience.index.compareTo(b.audience.index);
        if (byAudience != 0) return byAudience;
        final byBlock = a.exercise.blockId.compareTo(b.exercise.blockId);
        return byBlock != 0
            ? byBlock
            : a.exercise.number.compareTo(b.exercise.number);
      });

  return SeasonArchive(
    seasonId: season.id,
    audiences: audiences,
    exercises: lines,
  );
}
