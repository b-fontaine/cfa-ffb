import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';
import 'package:billard_cfa/shared/lib/failure.dart';

const _theta = 0x03b8;

/// Remplacements fixes de caractères que la fonte du document n'a pas ou que
/// le papier rend mal ; `θ` (absent d'Exo 2, présent dans deux séances) dépend
/// de la langue et vient du paramètre `thetaWord`.
const _replacements = <int, String>{
  0x00a0: ' ',
  0x202f: ' ',
  0x2009: ' ',
  0x2007: ' ',
  0x2011: '-',
  0x0009: ' ',
  0x000d: '',
};

/// Le texte [text] tel qu'il s'imprime avec la fonte de [measure] : les
/// caractères de la table de remplacement sont remplacés (`θ` par [thetaWord],
/// « thêta » en français,
/// espaces insécables en espaces), tout autre caractère absent de la fonte est
/// **refusé** (`InvariantViolation`, code `unprintableContent`, détail avec le
/// point de code) plutôt que dessiné en carré vide.
///
/// Le texte ne doit plus contenir de saut de ligne : la mise en page coupe les
/// lignes avant.
String printable(
  String text,
  TextMeasure measure, {
  required String thetaWord,
}) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final replacement = rune == _theta ? thetaWord : _replacements[rune];
    if (replacement != null) {
      out.write(replacement);
    } else if (measure.hasGlyph(rune)) {
      out.writeCharCode(rune);
    } else {
      final code = rune.toRadixString(16).toUpperCase().padLeft(4, '0');
      throw InvariantViolation(
        InvariantCode.unprintableContent,
        'U+$code absent de la fonte dans « $text »',
      );
    }
  }
  return out.toString();
}
