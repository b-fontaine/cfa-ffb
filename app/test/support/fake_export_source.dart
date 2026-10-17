import 'dart:async';

import 'package:billard_cfa/features/export_sheet/domain/export_source.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_labels.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_sheets_input.dart';
import 'package:billard_cfa/features/export_sheet/domain/sheet_print_input.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';

PrintLabels testPrintLabels() => PrintLabels(
  rundown: 'Run-down',
  columnTime: 'Time',
  columnStep: 'Step',
  columnMinutes: 'Min',
  total: (m) => 'Total: $m min',
  minutesNote: 'Minutes are [Prop]',
  proposalLegend: '[Prop]: proposal',
  sources: 'Sources',
  uncertainties: 'To check',
  illustrationAlt: 'Description:',
  ballLegend: 'R red',
  pageOf: (page, pages) => '$page / $pages',
  minutes: (m) => '$m min',
  thetaWord: 'thêta',
);

/// Libellés des fiches résultats, ceux de la fiche fédérale en français.
ResultsLabels testResultsLabels() => ResultsLabels(
  language: 'fr',
  title: 'Fiche Résultats',
  tabBrand: 'BLACKBALL',
  tabTitle: 'FICHE RESULTATS',
  sourceLine:
      'Source [S] : Fiche Résultats CFA Blackball, Direction Technique '
      'Nationale (grille reproduite).',
  notFederalLine:
      "Document produit par l'application Billard CFA : ce n'est pas un "
      'document fédéral.',
  name: 'Nom :',
  totalFirstLine: 'Nb de billes',
  totalSecondLine: 'empochées',
  attempt: 'ESSAI',
  attemptLegend: (n) => 'essai $n',
  session: 'Séance :',
  exercise: 'Exercice :',
  notion: 'Notion :',
  technique: 'Technique :',
  thetaWord: 'thêta',
);

/// Source d'export programmable : enregistre les publics demandés ; une
/// [gate] suspend la réponse tant qu'elle n'est pas complétée.
class FakeExportSource implements ExportSource {
  FakeExportSource({this.failure});

  /// Échec rendu par les deux méthodes.
  Failure? failure;

  /// Quand elle est posée, la réponse de [animator] et [results] attend.
  Completer<void>? gate;

  /// Texte du paragraphe de la feuille de l'animateur (varie avec le public).
  String Function(Audience audience) text = (a) => 'Texte ${a.name}';

  final List<Audience> animatorAsked = [];
  final List<Audience> resultsAsked = [];

  @override
  Future<Result<SheetPrintInput>> animator(Audience audience) async {
    animatorAsked.add(audience);
    await gate?.future;
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Ok(
      SheetPrintInput(
        fileName: 'seance-x-${audience.name}.pdf',
        title: 'Titre',
        shortTitle: 'Titre',
        language: 'fr',
        headerLines: ['Public ${audience.name}'],
        steps: [
          SheetPrintStep(
            phase: 'Phase',
            title: 'Étape',
            minutes: audience == Audience.children ? 90 : 120,
            blocks: [SheetPrintText(text(audience))],
          ),
        ],
        sources: const [],
        labels: testPrintLabels(),
      ),
    );
  }

  @override
  Future<Result<ResultsPlan>> results(Audience audience) async {
    resultsAsked.add(audience);
    await gate?.future;
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Ok(
      ResultsPlan(
        title: 'Fiches',
        fileName: 'fiches-x-${audience.name}.pdf',
        columns: 5,
        labels: testResultsLabels(),
        series: const [
          ResultsSeries(
            session: 'S',
            exercise: '1. E',
            notion: 'N',
            technique: 'T',
            attempts: 10,
          ),
        ],
      ),
    );
  }
}
