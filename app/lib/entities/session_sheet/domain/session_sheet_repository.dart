import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// Port de lecture du catalogue de séances (implémenté dans la couche data).
///
/// Lecture seule par construction : aucune méthode d'écriture. Le contenu est
/// embarqué ; seule la planification (`Session.sheetId`) est mutable.
abstract interface class SessionSheetRepository {
  /// Toutes les séances, dans l'ordre du catalogue (`order` croissant).
  Future<List<SessionSheet>> getAll();

  /// La séance d'identifiant [id], ou `null` si elle n'existe pas.
  Future<SessionSheet?> getById(SheetId id);
}
