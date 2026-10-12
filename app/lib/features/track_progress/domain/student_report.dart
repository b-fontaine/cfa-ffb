import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_report.freezed.dart';

/// Synthèse d'un élève : exercices validés, blocs, alertes actives.
@freezed
abstract class StudentReport with _$StudentReport {
  const factory StudentReport({
    required StudentId studentId,
    required int validatedCount,
    required int exerciseCount,
    required List<BlockProgress> blocks,
    required List<ExerciseResult> activeAlerts,
  }) = _StudentReport;
}
