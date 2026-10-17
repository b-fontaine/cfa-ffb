import 'package:freezed_annotation/freezed_annotation.dart';

/// Libellés fixes de la feuille de l'animateur : ceux que la mise en page écrit
/// elle-même (déroulé, légendes, pied de page). Ils suivent la langue de
/// l'interface ; la présentation les fournit depuis les fichiers ARB.
///
/// Le texte des séances (catalogue, en français) n'en fait pas partie. Les
/// marques de provenance `[S]`, `[FFB]`, `[Web]` et `[Prop]` ne se traduisent
/// pas.
@immutable
class PrintLabels {
  const PrintLabels({
    required this.rundown,
    required this.columnTime,
    required this.columnStep,
    required this.columnMinutes,
    required this.total,
    required this.minutesNote,
    required this.proposalLegend,
    required this.sources,
    required this.uncertainties,
    required this.illustrationAlt,
    required this.ballLegend,
    required this.pageOf,
    required this.minutes,
    required this.thetaWord,
  });

  /// Titre du tableau du déroulé.
  final String rundown;
  final String columnTime;
  final String columnStep;
  final String columnMinutes;

  /// « Total : 90 min ».
  final String Function(int minutes) total;

  /// Note sous le déroulé : les minutes sont des propositions `[Prop]`.
  final String minutesNote;

  /// Légende de `[Prop]`, imprimée en pied de chaque page.
  final String proposalLegend;
  final String sources;
  final String uncertainties;

  /// Introduit le texte alternatif d'une illustration non dessinée.
  final String illustrationAlt;

  /// Légende des lettres des billes d'un schéma.
  final String ballLegend;

  /// « 1 / 3 ».
  final String Function(int page, int pages) pageOf;

  /// « 15 min », à droite du titre d'une étape.
  final String Function(int minutes) minutes;

  /// Mot qui remplace `θ`, absent de la fonte du document.
  final String thetaWord;
}
