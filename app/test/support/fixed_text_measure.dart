import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';

/// Mesure à chasse fixe : chaque caractère fait [em] fois la taille du texte,
/// quel que soit le style. Les caractères de [missing] n'ont pas de glyphe.
class FixedTextMeasure implements TextMeasure {
  const FixedTextMeasure({this.em = 0.5, this.missing = const {}});

  final double em;
  final Set<int> missing;

  @override
  double width(String text, double size, PrintFontStyle style) =>
      text.runes.length * size * em;

  @override
  bool hasGlyph(int rune) => !missing.contains(rune);
}
