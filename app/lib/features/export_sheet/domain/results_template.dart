import 'package:billard_cfa/shared/lib/success_rate.dart';

/// Gabarit de la fiche résultats fédérale `[S]` (« Fiches résultats CFA
/// blackball.pdf », Direction Technique Nationale) : quatre blocs par page
/// A4, chacun avec son en-tête « Nom / ESSAI n / Nb de billes empochées » et
/// une grille de cinq colonnes d'essais sur un axe de 0 à 16.
///
/// Toutes les cotes sont en points, **mesurées sur le PDF fédéral** (textes
/// par `pdftotext -bbox`, traits par `pdftocairo -svg`) et exprimées pour le
/// premier bloc (en haut à gauche) ; les autres blocs sont décalés de
/// [blockPitchX] et [blockPitchY]. Le test `results_template_test` les compare
/// aux valeurs du PDF.
abstract final class ResultsTemplate {
  // --- Page ---

  static const double pageWidth = 595;
  static const double pageHeight = 842;

  // --- Blocs ---

  static const int blocksPerRow = 2;
  static const int blocksPerColumn = 2;
  static const int blocksPerPage = blocksPerRow * blocksPerColumn;

  /// Décalage horizontal entre deux blocs voisins (textes : 268,25 ; traits :
  /// 268,8).
  static const double blockPitchX = 268.5;

  /// Décalage vertical entre deux blocs superposés (textes : 381,79 ; traits :
  /// 381,2).
  static const double blockPitchY = 381.5;

  // --- En-tête ---

  /// Premier trait horizontal (haut des cases « ESSAI »).
  static const double headerTop = 60;

  /// Trait entre la ligne des « ESSAI » et celle des billes empochées.
  static const double headerMiddle = 87.8;

  /// Bas de la case des billes empochées.
  static const double headerBottom = 115.7;

  /// Bords gauche et droit de la case des billes empochées.
  static const double boxLeft = 11.2;
  static const double boxRight = 248.4;

  /// Marge gauche des libellés (« Nom : », « Séance : »…).
  static const double labelX = 14.4;

  // --- Grille ---

  /// Colonnes d'essais par défaut (`RulesConfig.passesRequired`).
  static const int defaultColumns = 5;

  /// Nombre minimal et maximal de colonnes imprimées.
  static const int minColumns = 3;
  static const int maxColumns = 8;

  /// Bord gauche de la grille (axe vertical noir).
  static const double gridLeft = 85.8;

  /// Largeur de la grille : celle de cinq colonnes de 32,5 points, conservée
  /// quel que soit le nombre de colonnes pour ne jamais toucher le bloc voisin.
  static const double gridWidth = 162.5;

  static const double gridTop = 128.4;
  static const double gridBottom = 370.9;

  /// Valeur maximale de l'axe : celle de `SuccessRate.maxAttempts` `[S]`.
  static const int scaleMax = SuccessRate.maxAttempts;

  /// Bandes de la grille : une par valeur de 0 à [scaleMax].
  static const int bands = scaleMax + 1;

  static const double bandHeight = (gridBottom - gridTop) / bands;

  // --- Colonne de gauche (valeurs préremplies) ---

  /// Largeur disponible à gauche de l'axe pour les valeurs préremplies.
  static const double leftColumnWidth = 58.6;

  // --- Onglet vertical de droite ---

  static const double tabX = 540;
  static const double tabY = 677.9;
  static const double tabWidth = 45.2;
  static const double tabHeight = 157.6;

  /// Largeur d'une colonne d'essais pour [columns] colonnes (la grille garde
  /// sa largeur).
  static double columnWidth(int columns) => gridWidth / columns;

  /// Nombre de colonnes imprimé pour [passesRequired] passages requis.
  static int clampColumns(int passesRequired) =>
      passesRequired.clamp(minColumns, maxColumns);

  /// Ordonnée du centre de la bande de la valeur [value] (0 en bas).
  static double bandCenter(int value) =>
      gridTop + (scaleMax - value + 0.5) * bandHeight;
}
