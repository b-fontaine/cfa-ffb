import 'dart:math' show Point;

import 'package:freezed_annotation/freezed_annotation.dart';

// Scène d'impression (ADR 0021) : ce que la mise en page produit et que deux
// interprètes rendent, le PDF (couche `data`) et l'aperçu à l'écran
// (présentation). Dart pur, en points (1/72 po), origine en haut à gauche,
// `y` vers le bas. Niveaux de gris seulement : le sens ne passe jamais par la
// couleur.

/// Style de fonte. Le gras est simulé par le rendu (la fonte est variable, une
/// seule instance est embarquée).
enum PrintFontStyle { regular, italic, bold, boldItalic }

/// Niveau de gris.
enum PrintShade { black, darkGray, lightGray, white }

/// Alignement horizontal du texte par rapport à son `x`.
enum PrintAlign { left, center, right }

/// Un élément dessiné sur une page. [tag] nomme sa fonction (`pocket`, `ball`,
/// `scale-label`…) : il sert aux tests et à l'accessibilité, jamais au rendu.
@immutable
sealed class PrintItem {
  const PrintItem({this.tag});

  final String? tag;
}

/// Une ligne de texte déjà coupée, posée sur sa ligne de base [y]. Une
/// [rotated] ligne se lit de haut en bas (quart de tour à droite) ; son point
/// d'ancrage reste ([x], [y]).
final class PrintText extends PrintItem {
  const PrintText({
    required this.x,
    required this.y,
    required this.text,
    required this.size,
    this.style = PrintFontStyle.regular,
    this.shade = PrintShade.black,
    this.align = PrintAlign.left,
    this.rotated = false,
    super.tag,
  });

  final double x;
  final double y;
  final String text;
  final double size;
  final PrintFontStyle style;
  final PrintShade shade;
  final PrintAlign align;
  final bool rotated;
}

/// Trait droit. [dash] : suite longueur tracée, longueur vide (vide = plein).
final class PrintLine extends PrintItem {
  const PrintLine({
    required this.from,
    required this.to,
    this.width = 0.5,
    this.shade = PrintShade.black,
    this.dash = const [],
    super.tag,
  });

  final Point<double> from;
  final Point<double> to;
  final double width;
  final PrintShade shade;
  final List<double> dash;
}

/// Ligne brisée (trajectoire d'une flèche).
final class PrintPolyline extends PrintItem {
  const PrintPolyline({
    required this.points,
    this.width = 0.8,
    this.shade = PrintShade.black,
    this.dash = const [],
    super.tag,
  });

  final List<Point<double>> points;
  final double width;
  final PrintShade shade;
  final List<double> dash;
}

/// Rectangle, rempli et/ou contouré.
final class PrintRect extends PrintItem {
  const PrintRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.fill,
    this.stroke,
    this.strokeWidth = 0.5,
    this.dash = const [],
    super.tag,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final PrintShade? fill;
  final PrintShade? stroke;
  final double strokeWidth;
  final List<double> dash;
}

/// Cercle, rempli et/ou contouré.
final class PrintCircle extends PrintItem {
  const PrintCircle({
    required this.center,
    required this.radius,
    this.fill,
    this.stroke,
    this.strokeWidth = 0.5,
    this.dash = const [],
    super.tag,
  });

  final Point<double> center;
  final double radius;
  final PrintShade? fill;
  final PrintShade? stroke;
  final double strokeWidth;
  final List<double> dash;
}

/// Polygone plein (pointe de flèche).
final class PrintPolygon extends PrintItem {
  const PrintPolygon({
    required this.points,
    this.fill = PrintShade.black,
    super.tag,
  });

  final List<Point<double>> points;
  final PrintShade fill;
}

/// Une page : sa taille et ses éléments, dans l'ordre de lecture.
@immutable
class PrintPage {
  const PrintPage({
    required this.width,
    required this.height,
    required this.items,
  });

  final double width;
  final double height;
  final List<PrintItem> items;
}

/// Un document : titre (propriété du PDF), langue (`fr`, `en`) et pages.
@immutable
class PrintDocument {
  const PrintDocument({
    required this.title,
    required this.language,
    required this.pages,
  });

  final String title;
  final String language;
  final List<PrintPage> pages;
}
