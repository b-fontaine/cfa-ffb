import 'package:billard_cfa/features/export_sheet/domain/results_sheets_input.dart';
import 'package:billard_cfa/features/export_sheet/domain/sheet_print_input.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Ce que les fiches résultats d'une séance impriment : le titre et le nom du
/// fichier, une série par exercice d'entraînement et le nombre de colonnes
/// d'essais (passages requis).
@immutable
class ResultsPlan {
  const ResultsPlan({
    required this.title,
    required this.fileName,
    required this.series,
    required this.columns,
    required this.labels,
  });

  final String title;
  final String fileName;
  final List<ResultsSeries> series;
  final int columns;

  /// Libellés fixes de la fiche, dans la langue de l'interface.
  final ResultsLabels labels;
}

/// Source de ce qu'on imprime d'une séance du catalogue, pour un public.
///
/// Port de la feature : la couche `app` l'implémente avec le déroulé de la
/// séance (`run_sheet`), qu'une feature ne peut pas importer (FSD). Aucune de
/// ses méthodes ne rend de donnée d'élève.
abstract interface class ExportSource {
  /// L'entrée de la feuille de l'animateur ; `NotFound('sheet', id)` si la
  /// séance n'existe pas.
  Future<Result<SheetPrintInput>> animator(Audience audience);

  /// Les séries des fiches résultats ; `NotFound('sheet', id)` si la séance
  /// n'existe pas.
  Future<Result<ResultsPlan>> results(Audience audience);
}
