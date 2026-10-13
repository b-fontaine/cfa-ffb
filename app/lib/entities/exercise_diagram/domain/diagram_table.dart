import 'dart:math' show Point;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'diagram_table.freezed.dart';

// Contenu d'une table transcrite (FORMAT.md : `balls`, `ghosts`, `arrows`,
// `zones`, `sequence`), en Dart pur. Le repère est celui des transcriptions :
// des cases, `x` ∈ [0, 8] le long de la table, `y` ∈ [0, 4] en travers, départ
// à gauche. Le design system a son propre modèle (`TableDiagramSpec`) : le
// domaine ne le connaît pas, la présentation fait la conversion.

/// Point du repère de la table, en cases.
typedef TablePoint = Point<double>;

/// Couleur d'une bille (FORMAT : `red`, `yellow`, `black`, `white`).
enum TableBallColor { red, yellow, black, white }

/// Rôle d'une bille (FORMAT : `cue`, `object`, `obstacle`).
enum TableBallRole { cue, object, obstacle }

/// Rôle d'un cercle creux (FORMAT : `cue_start`, `impact`).
enum TableGhostRole { cueStart, impact }

/// Nature d'une flèche (FORMAT : `object`, `cue`, `indication`).
enum TableArrowKind { object, cue, indication }

/// Bande sur laquelle une bille rebondit.
enum TableBand { top, bottom, left, right }

/// Les six poches (FORMAT : `tl`, `tm`, `tr`, `bl`, `bm`, `br`).
enum TablePocket { tl, tm, tr, bl, bm, br }

/// Quantité de bille (FORMAT : `full`, `three_quarter`, `half`, `quarter`,
/// `thin` ; `none` = non précisée, donc `null` dans le modèle).
enum TableContact { full, threeQuarter, half, quarter, thin }

/// Bille posée dans l'état initial.
@freezed
abstract class TableBall with _$TableBall {
  const factory TableBall({
    required String id,
    required TableBallColor color,
    required TablePoint at,
    TableBallRole? role,
    String? label,

    /// Ordre de tir quand le numéro à côté de la bille en est un.
    int? order,
  }) = _TableBall;
}

/// Cercle creux : où poser la blanche, ou où elle touche la cible.
@freezed
abstract class TableGhost with _$TableGhost {
  const factory TableGhost({
    required String id,
    required TablePoint at,
    required TableGhostRole role,

    /// Bille représentée par le cercle (FORMAT : `for`).
    String? forBallId,
    String? label,
  }) = _TableGhost;
}

/// Flèche de trajectoire ou d'indication.
@freezed
abstract class TableArrow with _$TableArrow {
  const factory TableArrow({
    required String id,
    required TableArrowKind kind,
    required List<TablePoint> path,
    String? ballId,
    @Default(<TableBand>[]) List<TableBand> bounces,
    TablePocket? pocket,
    String? label,
    String? note,
  }) = _TableArrow;
}

/// Zone rectangulaire mise en évidence.
@freezed
abstract class TableZone with _$TableZone {
  const factory TableZone({
    required String id,
    required TablePoint from,
    required TablePoint to,
    String? label,
  }) = _TableZone;
}

/// Un tir du déroulé, dans l'ordre du fichier.
@freezed
abstract class TableStep with _$TableStep {
  const factory TableStep({
    required String cueId,
    String? hitId,
    TableContact? contact,
    TablePocket? pocket,
    @Default(1) int repeat,

    /// Cercle `cue_start` d'où part la bille jouée ; `null` = sa position.
    String? fromGhostId,

    /// Champs du FORMAT sans valeur typée (`effect`, `attack`, `via`...),
    /// conservés tels que transcrits.
    @Default(<String, String>{}) Map<String, String> extras,
  }) = _TableStep;
}

/// Table d'un exercice : état initial, tracés et déroulé.
@freezed
abstract class DiagramTable with _$DiagramTable {
  const factory DiagramTable({
    required List<TableBall> balls,
    @Default(<TableGhost>[]) List<TableGhost> ghosts,
    @Default(<TableArrow>[]) List<TableArrow> arrows,
    @Default(<TableZone>[]) List<TableZone> zones,
    @Default(<TableStep>[]) List<TableStep> steps,
  }) = _DiagramTable;
}
