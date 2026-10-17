import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';

/// Coupe [text] en lignes d'au plus [maxWidth] points à la taille [size] :
/// aux espaces (répétés ramenés à un seul), aux sauts de ligne explicites, et
/// caractère par caractère pour un mot plus long qu'une ligne. Texte vide :
/// aucune ligne ; ligne vide entre deux paragraphes : conservée.
///
/// Une ligne qui tient pile dans [maxWidth] est conservée. Un caractère seul
/// plus large que [maxWidth] occupe quand même sa ligne (jamais de boucle).
List<String> wrapText(
  String text,
  double maxWidth,
  double size,
  PrintFontStyle style,
  TextMeasure measure,
) {
  if (text.isEmpty) return const [];
  double width(String s) => measure.width(s, size, style);
  final lines = <String>[];
  for (final paragraph in text.split('\n')) {
    final words = paragraph.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      lines.add('');
      continue;
    }
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (width(candidate) <= maxWidth) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) lines.add(current);
      current = '';
      var rest = word;
      while (width(rest) > maxWidth) {
        final cut = _longestPrefix(rest, maxWidth, width);
        lines.add(rest.substring(0, cut));
        rest = rest.substring(cut);
      }
      current = rest;
    }
    if (current.isNotEmpty) lines.add(current);
  }
  return lines;
}

/// Longueur (en unités de code) du plus long préfixe de [word] qui tient dans
/// [maxWidth], d'au moins un caractère entier.
int _longestPrefix(
  String word,
  double maxWidth,
  double Function(String) width,
) {
  var best = 0;
  var index = 0;
  for (final rune in word.runes) {
    final next = index + String.fromCharCode(rune).length;
    if (best > 0 && width(word.substring(0, next)) > maxWidth) break;
    best = next;
    index = next;
  }
  return best;
}
