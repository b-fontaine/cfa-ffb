import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';

/// Les sources réelles (`[S]`, `[FFB]`, `[Web]`) dont une séance reprend du
/// contenu, dans l'ordre de la hiérarchie des sources ; jamais `[Prop]`.
Set<Provenance> sourcedProvenances(SessionSheet sheet) {
  final found = <Provenance>{
    sheet.recall.src,
    for (final s in sheet.theorySections) s.src,
    for (final i in sheet.initiation) i.src,
    for (final e in sheet.exercises) e.src,
    sheet.game.src,
  }..remove(Provenance.prop);
  return {
    for (final p in Provenance.values)
      if (found.contains(p)) p,
  };
}
