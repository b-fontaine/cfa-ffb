import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'week_summary.freezed.dart';

/// Le travail des 7 derniers jours (aujourd'hui inclus).
@freezed
abstract class WeekSummary with _$WeekSummary {
  const factory WeekSummary({
    /// Premier jour de la fenêtre (J-6) et dernier (aujourd'hui).
    required DateTime from,
    required DateTime to,

    /// Passages saisis dans la fenêtre.
    required int passes,

    /// Exercices validés dans la fenêtre, par élève.
    required int validations,

    /// Séances données dans la fenêtre.
    required int sessions,
  }) = _WeekSummary;
}

/// Nombre de jours glissants de la semaine, aujourd'hui compris.
const weekDays = 7;

/// Résumé de la fenêtre [weekDays] jours finissant à [today] (jour près).
///
/// La date d'un passage est celle de sa séance. Une validation compte à la
/// date du passage qui l'a obtenue (`validatedOn`).
WeekSummary weekSummary({
  required DateTime today,
  required List<ExerciseAttempt> attempts,
  required Iterable<StudentProgress> progress,
  required List<SessionRecord> records,
}) {
  final to = today.dateOnly;
  final from = DateTime(to.year, to.month, to.day - (weekDays - 1));
  bool inWindow(DateTime date) {
    final day = date.dateOnly;
    return !day.isBefore(from) && !day.isAfter(to);
  }

  final validated = [
    for (final student in progress)
      for (final result in student.results.values)
        if (result.validatedOn case final on? when inWindow(on)) result,
  ];
  return WeekSummary(
    from: from,
    to: to,
    passes: attempts.where((attempt) => inWindow(attempt.date)).length,
    validations: validated.length,
    sessions: records.where((record) => inWindow(record.date)).length,
  );
}
