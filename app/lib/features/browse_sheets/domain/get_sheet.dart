import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_grouping.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : lire une séance du catalogue avec ce qu'elle référence.
///
/// La séance référence sans recopier : taux, chevalet et mention bronze sont
/// lus dans le catalogue d'entraînement (`ExerciseRef`) ; schémas d'exercice,
/// d'initiation et de jeu dans la bibliothèque de diagrammes (par
/// identifiant). Le minutage vient de `RulesConfig.shapes`. Des schémas
/// illisibles ne font pas échouer la lecture. Identifiant inconnu :
/// `NotFound('sheet', id)`.
@injectable
class GetSheet {
  GetSheet(this._sheets, this._catalogue, this._diagrams, this._rules);

  final SessionSheetRepository _sheets;
  final CatalogueRepository _catalogue;
  final DiagramRepository _diagrams;
  final RulesConfig _rules;

  Future<Result<SheetDetail>> call(SheetId id) => runGuarded(() async {
    final sheet = await _sheets.getById(id);
    if (sheet == null) throw NotFound('sheet', id.value);
    final all = await _sheets.getAll();
    final previousId = sheet.previous;
    final previous = previousId == null
        ? null
        : await _sheets.getById(previousId);
    final catalogue = await _catalogue.load();
    final specs = <String, ExerciseSpec>{};
    for (final exercise in sheet.exercises) {
      final spec = catalogue.exercise(exercise.ref);
      if (spec != null) specs[exercise.id] = spec;
    }
    final wanted = diagramIdsOf(sheet, previous);
    var unreadable = false;
    final diagrams = <String, ExerciseDiagram>{};
    try {
      final library = await _diagrams.load();
      for (final diagramId in wanted) {
        final diagram = library.byId(diagramId);
        if (diagram != null) diagrams[diagramId] = diagram;
      }
    } on InvariantViolation catch (violation) {
      // Seul « schéma illisible » est toléré ; le reste est une vraie erreur.
      if (violation.code != InvariantCode.invalidDiagram) rethrow;
      unreadable = true;
    }
    return SheetDetail(
      sheet: sheet,
      partCount: partCountOf(all, sheet.technique),
      previous: previous,
      exerciseSpecs: specs,
      diagrams: diagrams,
      diagramsUnreadable: unreadable,
      timings: {
        for (final audience in Audience.values)
          audience: sheetTiming(
            sheet,
            audience: audience,
            shapes: _rules.shapes,
          ),
      },
    );
  });
}
