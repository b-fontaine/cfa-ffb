import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// Bloc du rappel de résultats d'une séance : celui de la plus récente séance
/// précédente dont le bloc diffère du bloc principal [sheet], ou `null` s'il
/// n'y en a pas (première séance, ou tout le chemin est dans le même bloc).
///
/// La partie `k > 1` d'une technique suit la partie `k - 1` (même bloc) :
/// on remonte jusqu'au bloc de la technique précédente. `quart` et `finesse`
/// partagent un bloc : on remonte au-delà de `quart-1`. Le rappel
/// **théorique** de la séance, lui, porte toujours sur la séance précédente.
String? resultsRecallBlock(SessionSheet sheet, Iterable<SessionSheet> all) {
  final byId = {for (final s in all) s.id: s};
  final visited = <SheetId>{};
  var current = sheet.previous;
  while (current != null && visited.add(current)) {
    final candidate = byId[current];
    if (candidate == null) return null;
    if (candidate.catalogueBlock != sheet.catalogueBlock) {
      return candidate.catalogueBlock;
    }
    current = candidate.previous;
  }
  return null;
}
