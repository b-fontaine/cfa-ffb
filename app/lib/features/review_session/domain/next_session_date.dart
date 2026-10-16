import 'package:billard_cfa/shared/lib/date_only.dart';

/// La date de la séance suivante : le même jour de la semaine que la séance
/// donnée ([given]), la semaine suivante, avancée de 7 jours en 7 jours
/// jusqu'à être strictement après [today] (jour près).
///
/// Les jours sont comptés en date de calendrier, pas en 24 heures : le
/// changement d'heure ne décale jamais la proposition.
DateTime nextSameWeekday({required DateTime given, required DateTime today}) {
  final limit = today.dateOnly;
  var next = DateTime(given.year, given.month, given.day + 7);
  while (!next.isAfter(limit)) {
    next = DateTime(next.year, next.month, next.day + 7);
  }
  return next;
}

/// Les dates où la séance suivante peut être planifiée depuis le bilan :
/// de demain à un an après aujourd'hui, bornes comprises (décision U-3).
class PlannableDates {
  const PlannableDates._(this.first, this.last);

  /// Demain.
  final DateTime first;

  /// Aujourd'hui dans un an ; le 29 février devient le 28.
  final DateTime last;

  /// [date] est dans les bornes (jour près).
  bool contains(DateTime date) {
    final day = date.dateOnly;
    return !day.isBefore(first) && !day.isAfter(last);
  }

  /// [date] ramenée dans les bornes.
  DateTime clamp(DateTime date) {
    final day = date.dateOnly;
    if (day.isBefore(first)) return first;
    return day.isAfter(last) ? last : day;
  }
}

/// Les bornes de planification vues d'[today] (aucune dépendance à la date
/// déjà choisie).
PlannableDates plannableDates(DateTime today) {
  final day = today.dateOnly;
  var last = DateTime(day.year + 1, day.month, day.day);
  if (last.month != day.month) last = DateTime(day.year + 1, day.month + 1, 0);
  return PlannableDates._(DateTime(day.year, day.month, day.day + 1), last);
}
