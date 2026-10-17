import 'package:freezed_annotation/freezed_annotation.dart';

/// Libellés fixes des fiches résultats : ceux que la mise en page écrit
/// elle-même (la fiche fédérale `[S]`). Ils suivent la langue de l'interface ;
/// la présentation les fournit depuis les fichiers ARB, le domaine ne garde que
/// les dimensions.
@immutable
class ResultsLabels {
  const ResultsLabels({
    required this.language,
    required this.title,
    required this.tabBrand,
    required this.tabTitle,
    required this.sourceLine,
    required this.notFederalLine,
    required this.name,
    required this.totalFirstLine,
    required this.totalSecondLine,
    required this.attempt,
    required this.attemptLegend,
    required this.session,
    required this.exercise,
    required this.notion,
    required this.technique,
    required this.thetaWord,
  });

  /// Langue du document (propriété du fichier).
  final String language;

  /// Titre en haut de chaque page.
  final String title;

  /// Onglet vertical : la discipline, puis le nom de la fiche.
  final String tabBrand;
  final String tabTitle;

  /// Mention de la source `[S]` et précision que le document n'est pas
  /// fédéral, imprimées en pied de chaque page.
  final String sourceLine;
  final String notFederalLine;

  /// « Nom : », devant le prénom.
  final String name;

  /// « Nb de billes » puis « empochées », sur deux lignes.
  final String totalFirstLine;
  final String totalSecondLine;

  /// En-tête d'une colonne d'essai (« ESSAI », puis son numéro).
  final String attempt;

  /// Légende sous une colonne (« essai 3 »).
  final String Function(int number) attemptLegend;

  /// Libellés des valeurs préremplies, deux-points compris.
  final String session;
  final String exercise;
  final String notion;
  final String technique;

  /// Mot qui remplace `θ`, absent de la fonte du document.
  final String thetaWord;
}

/// Une série de fiches résultats : les grilles d'un exercice d'entraînement
/// d'une séance, avec ce que la fiche fédérale fait écrire à la main.
@immutable
class ResultsSeries {
  const ResultsSeries({
    required this.session,
    required this.exercise,
    required this.notion,
    required this.technique,
    this.attempts,
  });

  /// Titre de la séance (« Séance : »).
  final String session;

  /// Numéro et titre de l'exercice (« Exercice : »).
  final String exercise;

  /// Notion principale de la séance (« Notion : »).
  final String notion;

  /// Technique de la séance (« Technique : »).
  final String technique;

  /// Tentatives du taux de réussite de l'exercice (dénominateur de « Nb de
  /// billes empochées »), `null` quand il est inconnu : le dénominateur reste
  /// vierge.
  final int? attempts;
}

/// Entrée de la mise en page des fiches résultats : aucune donnée d'élève
/// sauf les [names] demandés explicitement (prénoms d'un groupe).
@immutable
class ResultsSheetsInput {
  const ResultsSheetsInput({
    required this.title,
    required this.series,
    required this.labels,
    this.names = const [],
    this.columns = 5,
  });

  /// Titre du document (propriété du fichier).
  final String title;

  final List<ResultsSeries> series;

  /// Libellés fixes, dans la langue du document.
  final ResultsLabels labels;

  /// Prénoms à imprimer en tête des grilles, dans l'ordre ; vide : grilles
  /// sans nom.
  final List<String> names;

  /// Colonnes d'essais demandées (passages requis) ; bornées à l'impression.
  final int columns;
}
