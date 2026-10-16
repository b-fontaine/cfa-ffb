import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'closed_season.freezed.dart';

/// Une ligne par exercice de l'archive, avec le titre de sa technique (lu au
/// catalogue). Aucun élève : seulement des cumuls.
@freezed
abstract class ExerciseLine with _$ExerciseLine {
  const factory ExerciseLine({
    required Audience audience,
    required String blockTitle,
    required int exerciseNumber,
    required int studentCount,
    required int attemptCount,
    required int potted,
    required int total,
  }) = _ExerciseLine;
}

/// Une saison close et ce qu'on en a gardé : des chiffres par public, sans
/// aucun nom (ADR 0019).
@freezed
abstract class ClosedSeason with _$ClosedSeason {
  const factory ClosedSeason({
    required Season season,
    required List<AudienceArchive> audiences,
    required List<ExerciseLine> exercises,
  }) = _ClosedSeason;
}
