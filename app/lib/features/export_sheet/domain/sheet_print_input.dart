import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_labels.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Un élément du contenu d'une étape de la feuille de l'animateur.
@immutable
sealed class SheetPrintBlock {
  const SheetPrintBlock();
}

/// Un paragraphe, précédé d'un [label] en gras quand il en a un ; [proposal]
/// y ajoute la marque `[Prop]` (élément proposé, non sourcé).
final class SheetPrintText extends SheetPrintBlock {
  const SheetPrintText(this.text, {this.label, this.proposal = false});

  final String? label;
  final String text;
  final bool proposal;
}

/// Une liste à puces, précédée d'un [label] quand il y en a un.
final class SheetPrintList extends SheetPrintBlock {
  const SheetPrintList(this.items, {this.label});

  final String? label;
  final List<String> items;
}

/// Un schéma de table dessiné, avec sa légende et sa description.
final class SheetPrintDiagram extends SheetPrintBlock {
  const SheetPrintDiagram({
    required this.table,
    required this.caption,
    this.description,
  });

  final DiagramTable table;
  final String caption;
  final String? description;
}

/// Une illustration que l'impression ne dessine pas : sa légende et son texte
/// alternatif, toujours présents dans le modèle de la séance.
final class SheetPrintCaption extends SheetPrintBlock {
  const SheetPrintCaption({required this.caption, required this.alt});

  final String caption;
  final String alt;
}

/// Une étape du déroulé : une ligne du tableau et une section du document.
@immutable
class SheetPrintStep {
  const SheetPrintStep({
    required this.phase,
    required this.title,
    required this.minutes,
    this.source,
    this.blocks = const [],
  });

  /// Phase de la séance (« Accueil », « Entraînement »…).
  final String phase;

  /// Titre de l'étape, repris dans le tableau et en tête de section.
  final String title;

  /// Minutes calculées par l'application (jamais recalculées à l'impression).
  final int minutes;

  /// Provenance de l'élément ; sa marque est imprimée, jamais sa couleur.
  final Provenance? source;
  final List<SheetPrintBlock> blocks;
}

/// Entrée de la mise en page de la feuille de l'animateur : une séance du
/// catalogue pour un public, **sans aucune donnée d'élève**.
@immutable
class SheetPrintInput {
  const SheetPrintInput({
    required this.fileName,
    required this.title,
    required this.shortTitle,
    required this.language,
    required this.headerLines,
    required this.steps,
    required this.sources,
    required this.labels,
    this.uncertainties = const [],
  });

  /// Nom du fichier PDF proposé.
  final String fileName;

  /// Titre de la séance (en-tête du document et propriété du fichier).
  final String title;

  /// Titre abrégé, en pied de page.
  final String shortTitle;

  /// Langue des libellés fixes (`fr`, `en`).
  final String language;

  /// Lignes sous le titre : public et durée, notion, technique, date.
  final List<String> headerLines;

  final List<SheetPrintStep> steps;

  /// Sources citées, une ligne chacune (rang, fichier, page).
  final List<String> sources;

  /// « Points à vérifier » de la séance, imprimés en petit.
  final List<String> uncertainties;

  final PrintLabels labels;
}
