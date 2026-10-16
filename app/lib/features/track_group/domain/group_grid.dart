import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/features/track_group/domain/group_alerts.dart';
import 'package:billard_cfa/features/track_group/domain/group_attendance.dart';
import 'package:billard_cfa/shared/lib/attendance.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_grid.freezed.dart';

/// Une colonne de la grille : un membre du groupe et son assiduité.
@freezed
abstract class GridStudent with _$GridStudent {
  const factory GridStudent({
    required StudentId id,
    required String firstName,
    required Attendance attendance,
  }) = _GridStudent;
}

/// Une ligne de la grille : la technique (un bloc du catalogue).
@freezed
abstract class GridTechnique with _$GridTechnique {
  const factory GridTechnique({
    required String blockId,
    required String title,
    required bool proposal,
    required int exerciseCount,
  }) = _GridTechnique;
}

/// Palier de la teinte d'une cellule, d'après sa fraction d'exercices faits :
/// aucun, moins de la moitié, au moins la moitié sans tout, tout.
enum HeatTier { none, some, most, all }

/// Une cellule (technique, élève) : sa fraction d'exercices validés ou acquis
/// et son statut, toujours exprimables en texte.
@freezed
abstract class GridCell with _$GridCell {
  const factory GridCell({
    required StudentId studentId,
    required BlockStatus status,

    /// Exercices validés ou acquis.
    required int doneCount,
    required int total,

    /// Alerte active (non acquittée) sur la technique.
    required bool alerted,
  }) = _GridCell;

  const GridCell._();

  /// Palier de teinte : `some` strictement sous la moitié, `most` dès la
  /// moitié exacte, `all` quand tout est fait.
  HeatTier get tier => doneCount == 0
      ? HeatTier.none
      : doneCount >= total
      ? HeatTier.all
      : doneCount * 2 < total
      ? HeatTier.some
      : HeatTier.most;
}

/// Une ligne de la grille et ses cellules, dans l'ordre des colonnes.
@freezed
abstract class GridRow with _$GridRow {
  const factory GridRow({
    required GridTechnique technique,
    required List<GridCell> cells,
  }) = _GridRow;

  const GridRow._();

  /// Élèves ayant terminé la technique (par passages ou acquise).
  List<StudentId> get finished => [
    for (final cell in cells)
      if (cell.status == BlockStatus.mastered ||
          cell.status == BlockStatus.acquiredAtPlacement)
        cell.studentId,
  ];

  /// Élèves qui ont commencé sans avoir terminé (y compris à revoir).
  List<StudentId> get inProgress => [
    for (final cell in cells)
      if (cell.status == BlockStatus.inProgress ||
          cell.status == BlockStatus.toReview)
        cell.studentId,
  ];

  /// Élèves qui n'ont encore rien fait de la technique.
  List<StudentId> get toStart => [
    for (final cell in cells)
      if (cell.status == BlockStatus.notStarted) cell.studentId,
  ];
}

/// La vue d'un groupe : carte de chaleur technique × élève, assiduité et
/// alertes de groupe.
@freezed
abstract class GroupGrid with _$GroupGrid {
  const factory GroupGrid({
    required GroupId groupId,
    required String name,
    required List<GridStudent> students,
    required List<GridRow> rows,
    required GroupAttendance attendance,
    required List<GroupAlert> alerts,
  }) = _GroupGrid;
}
