import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unique_name.dart';

/// L'année scolaire (1er septembre au 31 août) qui contient [day] ; l'année
/// suivante se prépare dès juillet.
Season schoolYearSeason(DateTime day, SeasonId id) {
  final startYear = day.month >= 7 ? day.year : day.year - 1;
  return Season(
    id: id,
    label: '$startYear-${startYear + 1}',
    startDate: DateTime(startYear, 9),
    endDate: DateTime(startYear + 1, 8, 31),
  );
}

/// La saison qui suit [previous] : elle commence le lendemain de la fin de
/// [previous] (ramenée au jour de clôture si elle est anticipée), mais pas
/// avant le 1er septembre quand ce lendemain tombe en juillet ou en août ;
/// elle finit le 31 août. Une clôture anticipée dans l'année scolaire donne
/// un libellé qui ne répète pas celui de la saison close (« 2026-2027 (2) »).
///
/// [takenLabels] : les libellés déjà portés par d'autres saisons ; le suffixe
/// s'incrémente (« (2) », « (3) »…) jusqu'à un libellé libre.
Season nextSeasonAfter(
  Season previous,
  SeasonId id, {
  Set<String> takenLabels = const {},
}) {
  final after = previous.endDate.add(const Duration(days: 1));
  final start = DateTime(after.year, after.month, after.day);
  final candidate = schoolYearSeason(start, id);
  final startDate = start.month == 7 || start.month == 8
      ? candidate.startDate
      : start;
  final label = candidate.label == previous.label
      ? firstFreeName(
          candidate.label,
          (c) => c == previous.label || takenLabels.contains(c),
        )
      : candidate.label;
  return Season(
    id: id,
    label: label,
    startDate: startDate,
    endDate: candidate.endDate,
  );
}
