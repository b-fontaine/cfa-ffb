import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_journey.freezed.dart';

/// Le parcours d'un groupe dans le catalogue : les séances déjà données et la
/// séance recommandée ensuite.
@freezed
abstract class GroupJourney with _$GroupJourney {
  const factory GroupJourney({
    /// Séances données, avec la date de la dernière fois (règle `givenSheets`).
    @Default(<SheetId, DateTime>{}) Map<SheetId, DateTime> done,

    /// La séance recommandée ensuite (celle de l'onglet Suggestion) ; `null`
    /// pour une notion sans séance du catalogue ou un groupe sans élève.
    SheetId? next,

    /// Le groupe n'a aucun élève aujourd'hui : pas de séance recommandée.
    @Default(false) bool noStudents,
  }) = _GroupJourney;

  const GroupJourney._();

  /// Marqueur d'une séance : recommandée, sinon faite, sinon à venir.
  JourneyMark markOf(SheetId id) {
    if (id == next) return JourneyMark.next;
    if (done.containsKey(id)) return JourneyMark.done;
    return JourneyMark.upcoming;
  }

  /// Un marqueur par séance de [ids] (jamais par technique).
  Map<SheetId, JourneyMark> marksFor(Iterable<SheetId> ids) => {
    for (final id in ids) id: markOf(id),
  };
}
