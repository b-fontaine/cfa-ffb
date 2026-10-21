import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_summary.freezed.dart';

/// Nombre d'éléments écrits par un import (fusion par identifiant) ;
/// [settings] : la sauvegarde contient les réglages du club.
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
    @Default(0) int alertAcknowledgements,
    @Default(0) int seasonArchives,
    @Default(false) bool settings,
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
    alertAcknowledgements: snapshot.alertAcknowledgements?.length ?? 0,
    seasonArchives: snapshot.seasonArchives.length,
    settings: snapshot.settings != null,
  );

  /// Le fichier ne contient rien que l'animateur ait saisi (les saisons et les
  /// réglages seuls ne sont pas un contenu à importer) : même définition que
  /// la détection des données de l'appareil, [LocalDataCounts.hasContent].
  bool get holdsNothing => !LocalDataCounts(
    students: students,
    groups: groups,
    seasons: seasons,
    sessionRecords: sessionRecords,
    attempts: attempts,
    plannedSessions: plannedSessions,
    assessments: assessments,
    blockAcquisitions: blockAcquisitions,
    seasonArchives: seasonArchives,
  ).hasContent;
}
