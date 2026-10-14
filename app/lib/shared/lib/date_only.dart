/// Comparaisons au jour près (la saisie et la planification raisonnent par
/// jour, jamais à l'heure).
extension DateOnly on DateTime {
  /// Même année, mois et jour, quelle que soit l'heure.
  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// La date à minuit (fuseau local), sans l'heure.
  DateTime get dateOnly => DateTime(year, month, day);
}
