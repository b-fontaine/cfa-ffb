import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// Règle unique du lien « séance planifiée / séance demandée ↔ saisie »
/// (ADR 0016) : une saisie est identifiée par (groupe, jour, séance du
/// catalogue). Le groupe est choisi par l'appelant (il passe les saisies du
/// groupe).
///
/// Deux séances du catalogue **différentes** ne sont jamais la même séance
/// donnée ; l'absence de séance du catalogue (`null`) est compatible avec
/// toute séance (saisie libre, ancienne saisie, planifiée sans séance).
bool sameSitting(SheetId? a, SheetId? b) => a == null || b == null || a == b;

/// La saisie de [records] qui correspond à la séance [sheet] donnée le [day],
/// ou `null`. À candidats multiples : l'égalité exacte (y compris
/// `null == null`) l'emporte, puis l'ordre de [records] (ordre de sauvegarde).
SessionRecord? recordFor(
  Iterable<SessionRecord> records,
  DateTime day,
  SheetId? sheet,
) {
  final candidates = [
    for (final record in records)
      if (record.date.isSameDayAs(day) && sameSitting(record.sheetId, sheet))
        record,
  ];
  return candidates.where((record) => record.sheetId == sheet).firstOrNull ??
      candidates.firstOrNull;
}
