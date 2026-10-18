import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'season.freezed.dart';

/// Une saison sportive (ex. « 2026-2027 »). Les élèves sont les mêmes toute
/// la saison `[U]`.
@freezed
abstract class Season with _$Season {
  factory Season({
    required SeasonId id,
    required String label,
    required DateTime startDate,
    required DateTime endDate,

    /// Jour de clôture ; `null` tant que la saison est ouverte (ADR 0019).
    DateTime? closedOn,
  }) = _Season;

  Season._() {
    if (label.trim().isEmpty) {
      throw const InvariantViolation(InvariantCode.blankName);
    }
    if (label.length > maxSeasonLabelLength) {
      throw const InvariantViolation(InvariantCode.nameTooLong);
    }
    if (!endDate.isAfter(startDate)) {
      throw const InvariantViolation(InvariantCode.invalidPeriod);
    }
    if (closedOn != null && closedOn!.isBefore(startDate)) {
      throw const InvariantViolation(InvariantCode.invalidPeriod);
    }
  }

  /// Vrai une fois la saison close : elle refuse toute nouvelle saisie,
  /// planification ou inscription.
  bool get isClosed => closedOn != null;

  /// La saison accepte du travail nouveau ce jour-là : non close et dans sa
  /// période. Remplace [contains] partout où l'on parle de « saison en cours »
  /// ou de travail nouveau ; [contains] reste la période seule (données
  /// historiques, sauvegarde).
  bool isOpenOn(DateTime date) => !isClosed && contains(date);

  /// Bornes incluses.
  bool contains(DateTime date) =>
      !date.isBefore(startDate) && !date.isAfter(endDate);

  /// Deux saisons ne doivent pas se chevaucher.
  bool overlaps(Season other) =>
      !startDate.isAfter(other.endDate) && !other.startDate.isAfter(endDate);
}
