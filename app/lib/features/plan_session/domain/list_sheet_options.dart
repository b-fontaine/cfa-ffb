import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les séances du catalogue qu'une séance planifiée peut suivre,
/// dans l'ordre d'enseignement (`sheetOptionsOf`).
@injectable
class ListSheetOptions {
  ListSheetOptions(this._repository);

  final SessionSheetRepository _repository;

  Future<Result<List<SheetOption>>> call() =>
      runGuarded(() async => sheetOptionsOf(await _repository.getAll()));
}
