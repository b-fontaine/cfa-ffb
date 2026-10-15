import 'dart:math' show Point;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/cue_side_geometry.dart';
import 'package:billard_cfa/shared/lib/player_figure_layout.dart';
import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'illustration.freezed.dart';

// Illustrations d'une séance du catalogue : énumération fermée de types
// générés (FORMAT des séances § 6), jamais de photo. Dart pur : le rendu est
// fait par `shared/ui` et `entities/session_sheet/presentation`.
//
// Le repère des tables est celui des diagrammes : `x` ∈ [0, 8] le long de la
// table, `y` ∈ [0, 4] en travers, origine en haut à gauche.

/// Hauteur du procédé sur la blanche (vue de côté).
enum CueHeight { high, level, low }

/// Nature de la marque d'angle d'une illustration `angle`.
enum AngleKind { bounce, naturalRejection, rightAngle }

/// Couleur d'une bille d'une illustration `table`.
enum IllustrationBallColor { red, yellow, black, white }

/// Rôle d'une bille (FORMAT des diagrammes : `cue`, `object`, `obstacle`).
enum IllustrationBallRole { cue, object, obstacle }

/// Rôle d'un cercle creux (`cue_start`, `impact`).
enum IllustrationGhostRole { cueStart, impact }

/// Nature d'une flèche (`object`, `cue`, `indication`).
enum IllustrationArrowKind { object, cue, indication }

/// Bande sur laquelle une bille rebondit.
enum IllustrationBand { top, bottom, left, right }

/// Bille posée dans l'état initial d'une illustration `table`.
@freezed
abstract class IllustrationBall with _$IllustrationBall {
  const factory IllustrationBall({
    required String id,
    required IllustrationBallColor color,
    required Point<double> at,
    IllustrationBallRole? role,
    String? label,
    int? order,
  }) = _IllustrationBall;
}

/// Cercle creux : où poser la blanche, ou où elle touche la cible.
@freezed
abstract class IllustrationGhost with _$IllustrationGhost {
  const factory IllustrationGhost({
    required String id,
    required Point<double> at,
    required IllustrationGhostRole role,
    String? forBallId,
    String? label,
  }) = _IllustrationGhost;
}

/// Flèche de trajectoire ou d'indication.
@freezed
abstract class IllustrationArrow with _$IllustrationArrow {
  const factory IllustrationArrow({
    required String id,
    required IllustrationArrowKind kind,
    required List<Point<double>> path,
    String? ballId,
    @Default(<IllustrationBand>[]) List<IllustrationBand> bounces,
    TablePocket? pocket,
    String? label,
    String? note,
  }) = _IllustrationArrow;
}

/// Zone rectangulaire mise en évidence.
@freezed
abstract class IllustrationZone with _$IllustrationZone {
  const factory IllustrationZone({
    required String id,
    required Point<double> from,
    required Point<double> to,
    String? label,
  }) = _IllustrationZone;
}

/// Un tir du déroulé, dans l'ordre du fichier.
@freezed
abstract class IllustrationStep with _$IllustrationStep {
  const factory IllustrationStep({
    required String cueId,
    String? hitId,
    ContactFraction? contact,
    TablePocket? pocket,
    @Default(1) int repeat,
    String? fromGhostId,

    /// Champs du FORMAT sans valeur typée (`effect`, `attack`...), tels que
    /// transcrits.
    @Default(<String, String>{}) Map<String, String> extras,
  }) = _IllustrationStep;
}

/// Illustration d'une séance : légende affichée ([caption]), texte alternatif
/// non vide ([alt]) et un type parmi une liste fermée.
///
/// Une illustration prend la provenance de l'élément qui la référence.
@freezed
sealed class Illustration with _$Illustration {
  /// Schéma d'un diagramme transcrit : seul son identifiant est porté, le
  /// rendu est résolu en `pages` (`DiagramLibrary.byId`).
  const factory Illustration.diagramRef({
    required String id,
    required String caption,
    required String alt,
    required String diagramId,
  }) = DiagramRefIllustration;

  /// Table dessinée dans la séance (mêmes clés que le FORMAT des diagrammes).
  const factory Illustration.table({
    required String id,
    required String caption,
    required String alt,
    required List<IllustrationBall> balls,
    @Default(<IllustrationGhost>[]) List<IllustrationGhost> ghosts,
    @Default(<IllustrationArrow>[]) List<IllustrationArrow> arrows,
    @Default(<IllustrationZone>[]) List<IllustrationZone> zones,
    @Default(<IllustrationStep>[]) List<IllustrationStep> steps,
  }) = TableIllustration;

  /// Une quantité de bille et le point d'impact du procédé.
  const factory Illustration.contact({
    required String id,
    required String caption,
    required String alt,
    required ContactFraction fraction,
    required TipPoint tipPoint,

    /// Écart du procédé au centre (« un peu au-dessus » : `slight`).
    @Default(TipOffset.half) TipOffset offset,

    /// Dessine les trajectoires après le contact (bille de couleur dans la
    /// ligne des centres, blanche sur la tangente) et l'angle de déviation.
    @Default(false) bool paths,
  }) = ContactIllustration;

  /// Rangée de quantités de bille, l'une pouvant être mise en évidence.
  const factory Illustration.contactStrip({
    required String id,
    required String caption,
    required String alt,
    required List<ContactFraction> fractions,
    ContactFraction? highlight,
  }) = ContactStripIllustration;

  /// Table avec bille fantôme et ligne de visée (position calculée).
  const factory Illustration.ghostAim({
    required String id,
    required String caption,
    required String alt,
    required Point<double> cue,
    required Point<double> object,
    required TablePocket pocket,
    required ContactFraction fraction,
  }) = GhostAimIllustration;

  /// Cible sur la blanche vue de face : le point d'impact du procédé, avec
  /// en option des points de comparaison et la hauteur de la queue.
  const factory Illustration.cueBallTarget({
    required String id,
    required String caption,
    required String alt,
    required TipPoint tipPoint,
    @Default(<TipPoint>[]) List<TipPoint> compare,
    CueHeight? cueHeight,

    /// Écart du procédé au centre (« un peu au-dessus » : `slight`).
    @Default(TipOffset.half) TipOffset offset,
  }) = CueBallTargetIllustration;

  /// Joueur schématique (pictogramme neutre) : de profil, de dessus ou les
  /// deux, avec des repères numérotés et légendés.
  const factory Illustration.playerFigure({
    required String id,
    required String caption,
    required String alt,
    @Default(PlayerView.side) PlayerView view,
    @Default(PlayerMark.values) List<PlayerMark> focus,
    LeadEye? leadEye,
    HeadCase? headCase,
    @Default(CueBridge.frame) CueBridge bridge,

    /// Gaucher : la figure est mise en miroir et la légende inverse les côtés.
    @Default(Handedness.right) Handedness handedness,
  }) = PlayerFigureIllustration;

  /// Comparaison de taille à l'échelle : la blanche (48,0 mm) à côté d'une
  /// bille de but (50,8 mm), avec les deux diamètres écrits.
  const factory Illustration.ballSize({
    required String id,
    required String caption,
    required String alt,
  }) = BallSizeIllustration;

  /// Contact de deux billes inégales, vue de côté : le contact est
  /// légèrement au-dessus de l'équateur de la blanche (fiche n° 4 `[S]`).
  /// L'écart, 1,62° en réalité, est exagéré ×10 et signalé : aucun paramètre.
  const factory Illustration.contactHeight({
    required String id,
    required String caption,
    required String alt,
  }) = ContactHeightIllustration;

  /// Plan amplitude × vitesse avec trois zones (doux, moyen, puissant) et des
  /// exemples placés.
  const factory Illustration.powerRatio({
    required String id,
    required String caption,
    required String alt,
    @Default(<PowerPoint>[]) List<PowerPoint> points,
    int? highlight,
    String? distanceLabel,
  }) = PowerRatioIllustration;

  /// Marque d'angle sur une table.
  const factory Illustration.angle({
    required String id,
    required String caption,
    required String alt,
    required AngleKind kind,
    required Point<double> vertex,
    required List<Point<double>> rays,
  }) = AngleIllustration;

  /// Renvoi au PDF fédéral : texte seul, jamais d'image.
  const factory Illustration.pdfRef({
    required String id,
    required String caption,
    required String alt,
    required String file,
    required int page,
  }) = PdfRefIllustration;
}
