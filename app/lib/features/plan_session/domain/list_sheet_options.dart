import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_grouping.dart';
import 'package:billard_cfa/features/plan_session/domain/sheet_option.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les séances du catalogue qu'une séance planifiée peut suivre,
/// dans l'ordre d'enseignement (techniques puis parties croissantes, voir
/// `groupByTechnique`).
@injectable
class ListSheetOptions {
  ListSheetOptions(this._repository);

  final SessionSheetRepository _repository;

  Future<Result<List<SheetOption>>> call() => runGuarded(() async {
    final groups = groupByTechnique(await _repository.getAll());
    return List<SheetOption>.unmodifiable([
      for (final group in groups)
        for (final sheet in group.sheets)
          SheetOption(
            id: sheet.id,
            technique: group.technique,
            techniqueRank: group.rank,
            title: sheet.title,
            part: sheet.part,
            partCount: group.partCount,
          ),
    ]);
  });
}
