import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_summary.freezed.dart';

/// Nombre d'éléments écrits par un import (fusion par identifiant).
@freezed
abstract class ImportSummary with _$ImportSummary {
  const factory ImportSummary({
    required int seasons,
    required int students,
    required int groups,
    required int sessionRecords,
    required int attempts,
    required int assessments,
    required int plannedSessions,
    required int blockAcquisitions,
  }) = _ImportSummary;

  const ImportSummary._();

  factory ImportSummary.of(BackupSnapshot snapshot) => ImportSummary(
    seasons: snapshot.seasons.length,
    students: snapshot.students.length,
    groups: snapshot.groups.length,
    sessionRecords: snapshot.sessionRecords.length,
    attempts: snapshot.attempts.length,
    assessments: snapshot.assessments.length,
    plannedSessions: snapshot.plannedSessions.length,
    blockAcquisitions: snapshot.blockAcquisitions.length,
  );
}
