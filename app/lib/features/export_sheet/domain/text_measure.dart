import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';

/// Port de mesure du texte : la largeur d'un texte dans la fonte du document.
///
/// Le rendu PDF le fournit avec les métriques de la fonte embarquée : la
/// coupure des lignes et le dessin utilisent donc la même mesure. Les tests
/// fournissent une mesure à chasse fixe.
abstract interface class TextMeasure {
  /// Largeur, en points, de [text] à la taille [size] dans le style [style].
  double width(String text, double size, PrintFontStyle style);

  /// Vrai quand la fonte sait dessiner le caractère [rune] (point de code).
  bool hasGlyph(int rune);
}
