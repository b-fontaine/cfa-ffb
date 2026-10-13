import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_grouping.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les séances du catalogue, groupées par technique.
///
/// Les techniques suivent l'ordre d'enseignement (ordre des séances), les
/// séances d'une technique leur partie croissante (`groupByTechnique`).
/// Lecture seule.
@injectable
class ListSheets {
  ListSheets(this._repository);

  final SessionSheetRepository _repository;

  Future<Result<SheetCatalogue>> call() => runGuarded(() async {
    final groups = groupByTechnique(await _repository.getAll());
    return SheetCatalogue(
      groups: [
        for (final group in groups)
          TechniqueGroup(
            rank: group.rank,
            technique: group.technique,
            title: group.sheets.first.title,
            partCount: group.partCount,
            sheets: group.sheets,
          ),
      ],
    );
  });
}
