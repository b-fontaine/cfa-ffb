import 'dart:math' show Point;

import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

export 'package:billard_cfa/shared/ui/ball_kind.dart';

part 'table_diagram_spec.freezed.dart';

// Modèle de données d'un schéma d'exercice, aligné sur le FORMAT des
// transcriptions (`docs/knowledge/03-exercices/diagrammes/FORMAT.md`).
//
// Dart pur (aucune dépendance Flutter ni domaine) : le repère est celui de la
// table, en cases (`x` ∈ [0, 8] le long de la table, `y` ∈ [0, 4] en travers,
// départ à gauche). Source unique des notions partagées : poches, couleur de
// bille (`BallKind`), quantité de bille (`ContactFraction`), dimensions
// (`BlackballDimensions`). Les modèles ont une égalité de valeur (freezed).

/// Dimensions de la table dans le repère des schémas, en cases.
abstract final class DiagramLayout {
  /// Nombre de cases dans la longueur.
  static const double columns = BlackballDimensions.columns;

  /// Nombre de cases dans la largeur.
  static const double rows = BlackballDimensions.rows;

  /// Position de la ligne de départ (`[FFB]`, voir FORMAT.md) : x = 1,6
  /// (1/5 de la longueur).
  static const double headStringX = BlackballDimensions.headString;
}

/// Point du repère de la table, en cases (`x` le long, `y` en travers).
typedef DiagramPoint = Point<double>;

/// Interpolation entre deux points du repère de la table.
extension DiagramPointMath on DiagramPoint {
  /// Point situé à la fraction [t] (0 à 1) du segment vers [other].
  DiagramPoint lerp(DiagramPoint other, double t) =>
      DiagramPoint(x + (other.x - x) * t, y + (other.y - y) * t);
}

/// Rôle d'une bille (FORMAT : `cue`, `object`, `obstacle`).
enum DiagramBallRole { cue, object, obstacle }

/// Rôle d'un repère circulaire (FORMAT : `cue_start`, `impact`) ; `contact`
/// est le point de contact entre deux billes, petit point plein des
/// illustrations de visée (hors FORMAT).
enum DiagramGhostRole { cueStart, impact, contact }

/// Nature d'une flèche (FORMAT : `object`, `cue`, `indication`) ; `aim` est la
/// ligne de visée des illustrations de séance (blanche vers bille fantôme),
/// tracée en trait-point.
enum DiagramArrowKind { object, cue, indication, aim }

/// Bande sur laquelle une bille rebondit.
enum DiagramBand { top, bottom, left, right }

/// Les six poches (FORMAT : `tl`, `tm`, `tr`, `bl`, `bm`, `br`).
enum DiagramPocket {
  tl(DiagramPoint(0, 0)),
  tm(DiagramPoint(4, 0)),
  tr(DiagramPoint(8, 0)),
  bl(DiagramPoint(0, 4)),
  bm(DiagramPoint(4, 4)),
  br(DiagramPoint(8, 4));

  DiagramPocket(this.point);

  /// Centre de la poche.
  final DiagramPoint point;
}

/// Bille posée sur la table dans l'état initial.
@freezed
abstract class DiagramBall with _$DiagramBall {
  const factory DiagramBall({
    required String id,

    /// Couleur (FORMAT : `red`, `yellow`, `black`, `white`).
    required BallKind color,
    required DiagramPoint at,
    DiagramBallRole? role,

    /// Numéro ou repère écrit à côté de la bille (« 3 », « x4 »).
    String? label,

    /// Ordre de tir quand le numéro à côté de la bille en est un (FORMAT :
    /// `order`).
    int? order,
  }) = _DiagramBall;
}

/// Cercle creux du schéma : où poser la blanche, ou où elle touche la cible.
@freezed
abstract class DiagramGhost with _$DiagramGhost {
  const factory DiagramGhost({
    required String id,
    required DiagramPoint at,
    required DiagramGhostRole role,

    /// Bille représentée par le cercle (FORMAT : `for`).
    String? forBallId,

    /// Numéro du cercle (ordre de pose de la blanche).
    String? label,
  }) = _DiagramGhost;
}

/// Flèche de trajectoire ou d'indication.
@freezed
abstract class DiagramArrow with _$DiagramArrow {
  const factory DiagramArrow({
    required String id,
    required DiagramArrowKind kind,

    /// Points de la ligne brisée ; un point par rebond sur une bande.
    required List<DiagramPoint> path,

    /// Bille qui suit la trajectoire (absente pour une indication libre).
    String? ballId,

    /// Bandes touchées, dans l'ordre (FORMAT : `bounces`).
    @Default(<DiagramBand>[]) List<DiagramBand> bounces,

    /// Poche visée (FORMAT : `to`).
    DiagramPocket? pocket,

    /// Texte court écrit sur la flèche (FORMAT : `label`).
    String? label,

    /// Précision de lecture, en clair (FORMAT : `note`).
    String? note,
  }) = _DiagramArrow;

  const DiagramArrow._();

  /// Points de rebond : les points intérieurs du tracé, quand leur nombre est
  /// celui des bandes touchées ; sinon aucun.
  List<DiagramPoint> get bouncePoints =>
      bounces.isNotEmpty && path.length == bounces.length + 2
      ? path.sublist(1, path.length - 1)
      : const [];
}

/// Zone mise en évidence (rectangle).
@freezed
abstract class DiagramZone with _$DiagramZone {
  const factory DiagramZone({
    required String id,
    required DiagramPoint from,
    required DiagramPoint to,

    /// Légende de la zone (FORMAT : `label`).
    String? label,
  }) = _DiagramZone;
}

/// Texte posé sur la table, à côté d'un point (« 90° », « Bille fantôme »).
///
/// Le texte est fourni tel quel par l'appelant, déjà localisé.
@freezed
abstract class DiagramAnnotation with _$DiagramAnnotation {
  const factory DiagramAnnotation({
    required String id,
    required DiagramPoint at,
    required String text,
  }) = _DiagramAnnotation;
}

/// Un tir du déroulé : la blanche touche une bille, qui part vers une poche.
@freezed
abstract class DiagramStep with _$DiagramStep {
  const factory DiagramStep({
    /// Bille jouée (la blanche, ou la bille visée d'un jeu de placement).
    required String cueId,

    /// Bille touchée ; `null` quand la bille jouée ne doit en toucher aucune.
    String? hitId,

    /// Quantité de bille ; `null` quand le schéma ne la précise pas (FORMAT :
    /// `none`).
    ContactFraction? contact,

    /// Poche visée par la bille touchée.
    DiagramPocket? pocket,

    /// Nombre de répétitions demandées (« x 4 »).
    @Default(1) int repeat,

    /// Cercle `cue_start` d'où part la blanche (FORMAT : `from`).
    String? fromGhostId,

    /// Champs de lecture du FORMAT que la timeline n'interprète pas (`effect`,
    /// `attack`, `via`, `then_cue_to`...), conservés tels que transcrits.
    @Default(<String, String>{}) Map<String, String> extras,
  }) = _DiagramStep;
}

/// Schéma complet d'un exercice.
@freezed
abstract class TableDiagramSpec with _$TableDiagramSpec {
  const factory TableDiagramSpec({
    required String id,
    required List<DiagramBall> balls,
    @Default(<DiagramGhost>[]) List<DiagramGhost> ghosts,
    @Default(<DiagramArrow>[]) List<DiagramArrow> arrows,
    @Default(<DiagramZone>[]) List<DiagramZone> zones,
    @Default(<DiagramStep>[]) List<DiagramStep> steps,

    /// Textes posés sur la table.
    @Default(<DiagramAnnotation>[]) List<DiagramAnnotation> annotations,
  }) = _TableDiagramSpec;
}
